# Prints the run state of a commit GitLab holds, read off its latest
# pipeline. Loaded after shape.awk and runs.awk.
#
# Input: a commit as the commits endpoint returns it, with .last_pipeline
#        a null when no pipeline ever ran on it.
# Output: {carried: true, state: "none"|"pending"|"success"|"failure", url}

function main(line) {
  tree_line(line)
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  pipeline = member(ROOT, "last_pipeline")
  print "0." wrap("carried") ":bool=true"
  print_str(0, "state", run_state(pipeline))
  print_or(member(pipeline, "web_url"), 0, "url", "str=\"\"")
}

{ main($0) }
