# Prints the open merge requests as the merge requests endpoint lists
# them, each as its iid, its head, the branch it targets and the labels it
# carries. Loaded after shape.awk.
#
# Input:  [{iid, sha, target_branch, labels: [name], ...}, ...]
# Output: [{iid, head, target, labels}, ...]
#
#   [{"iid":555,"sha":"b3d27cf9","target_branch":"main","labels":["type/feature"],"squash":false}]
#     ->  [{"iid":555,"head":"b3d27cf9","target":"main","labels":["type/feature"]}]

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

  reviews = 0
  for (review = NODE_FIRST[ROOT]; review != 0; review = NODE_NEXT[review]) {
    print_open(0, reviews, "map")
    print_as(member(review, "iid"), 1, "iid")
    print_as(member(review, "sha"), 1, "head")
    print_as(member(review, "target_branch"), 1, "target")
    print_or(member(review, "labels"), 1, "labels", "list")
    reviews++
  }

  if (reviews == 0) {
    print "0.:list"
  }
}

{ main($0) }
