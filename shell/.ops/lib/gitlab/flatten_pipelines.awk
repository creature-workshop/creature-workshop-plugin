# Reshapes the pipelines GitLab's REST API lists into the runs the forge
# contract answers with: each as its id, a str.
#
# Input:  [{id: 4248, sha, ref, status, created_at, ...}, ...]
# Output: [{id: "4248"}, ...]

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

  runs = 0
  for (pipeline = NODE_FIRST[ROOT]; pipeline != 0; pipeline = NODE_NEXT[pipeline]) {
    print_open(0, runs, "map")
    print_str(1, "id", text_of(member(pipeline, "id")))
    runs++
  }

  if (runs == 0) {
    print "0.:list"
  }
}

{ main($0) }
