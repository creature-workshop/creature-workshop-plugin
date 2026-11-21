# Prints a landed merge request as check C reads it
# (lib/releases/_tested.sh): the head that was merged, GitLab's own ref for
# that head, and the run on the head as GitLab holds it. Loaded after
# shape.awk and runs.awk.
#
# Input:  a merge request as the merge requests endpoint returns it
# Output: {iid, head, head_ref, run: {sha, state}}
#
#   {"iid": 12, "sha": "b3d2", "head_pipeline": {"sha": "b3d2", "status": "success"}}
#     ->  {"iid": 12, "head": "b3d2", "head_ref": "refs/merge-requests/12/head",
#          "run": {"sha": "b3d2", "state": "success"}}

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

  pipeline = member(ROOT, "head_pipeline")
  print_as(member(ROOT, "iid"), 0, "iid")
  print_as(member(ROOT, "sha"), 0, "head")
  print_str(0, "head_ref", "refs/merge-requests/" text_of(member(ROOT, "iid")) "/head")
  print_open(0, wrap("run"), "map")
  print_or(member(pipeline, "sha"), 1, "sha", "str=\"\"")
  print_str(1, "state", run_state(pipeline))
}

{ main($0) }
