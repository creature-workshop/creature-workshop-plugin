# Reshapes a merge request, with its head pipeline and that pipeline's
# jobs, into the shape the escape check and the record collection read:
# which jobs left an artifacts archive, and whether each has finished.
#
# Input:  {iid, targetBranch, headPipeline: {id, status,
#           jobs: {nodes: [{id, name, status, artifacts: {nodes: [{fileType}]}}]}}}
# Output: {iid, base, pipeline: {id, status} | null,
#          jobs: [{id, name, status, archive}]}
#
# GraphQL ids are gid://gitlab/Ci::Build/123. The REST endpoints the
# archive is downloaded from take the number at the end.

function main(line) {
  tree_line(line)
}

# What the number at the end of a GraphQL id writes after a key: a str, and
# a null for an id that is missing or empty.
function numeric_id(id) {
  if (text_or(id, "") == "") {
    return "null"
  }

  return "str=" wrap(after_last_slash(text_of(id)))
}

# Whether a job's artifacts include the archive of what it kept.
function has_archive(job, __artifact) {
  for (__artifact = NODE_FIRST[member(member(job, "artifacts"), "nodes")]; __artifact != 0; __artifact = NODE_NEXT[__artifact]) {
    if (text_of(member(__artifact, "fileType")) == "ARCHIVE") {
      return "true"
    }
  }

  return "false"
}

# Prints the pipeline, or a null when the merge request has none yet.
function print_pipeline(pipeline) {
  if (!is_present(pipeline)) {
    print "0." wrap("pipeline") ":null"
    return
  }

  print_open(0, wrap("pipeline"), "map")
  print "1." wrap("id") ":" numeric_id(member(pipeline, "id"))
  print_as(member(pipeline, "status"), 1, "status")
}

# Prints the jobs of the pipeline as the check reads them.
function print_jobs(pipeline, __job, __jobs) {
  print_open(0, wrap("jobs"), "list")

  __jobs = 0
  for (__job = NODE_FIRST[member(member(pipeline, "jobs"), "nodes")]; __job != 0; __job = NODE_NEXT[__job]) {
    print_open(1, __jobs, "map")
    print "2." wrap("id") ":" numeric_id(member(__job, "id"))
    print_as(member(__job, "name"), 2, "name")
    print_as(member(__job, "status"), 2, "status")
    print "2." wrap("archive") ":bool=" has_archive(__job)
    __jobs++
  }
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  print_as(member(ROOT, "iid"), 0, "iid")
  print_as(member(ROOT, "targetBranch"), 0, "base")
  print_pipeline(member(ROOT, "headPipeline"))
  print_jobs(member(ROOT, "headPipeline"))
}

{ main($0) }
