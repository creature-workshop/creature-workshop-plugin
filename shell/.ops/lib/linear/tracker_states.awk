# Prints the states of a team record, by position, each with its type, as
# a list. Loaded after tracker_issue.awk.

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

  order_children(member(member(ROOT, "states"), "nodes"), "position")
  for (i = 1; i <= ORDERED_COUNT; i++) {
    print_open(0, i - 1, "map")
    print_state(ORDERED[i], 1)
  }

  if (ORDERED_COUNT == 0) {
    print "0.:list"
  }
}

{ main($0) }
