# Prints the run GitLab answers a landing run's creation with, in the shape
# the landing run role answers one in. Loaded after runs.awk.
#
# Input:  the pipeline, {id, sha, status}
# Output: {id, sha, status}, the status as landing_status names it
#
#   {"id":7035,"sha":"24d3b90f","status":"created"}
#     ->  {"id":"7035","sha":"24d3b90f","status":"running"}

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

  print_run(ROOT, 0)
}

{ main($0) }
