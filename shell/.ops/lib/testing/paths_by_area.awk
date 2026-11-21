# Prints each area's paths, the empty list for an area with none.
#
# Input: the areas.

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

  areas = 0
  for (area = NODE_FIRST[ROOT]; area != 0; area = NODE_NEXT[area]) {
    if (is_present(member(area, "paths"))) {
      print_node(member(area, "paths"), 0, NODE_KEY[area])
    } else {
      print_open(0, NODE_KEY[area], "list")
    }
    areas++
  }

  if (areas == 0) {
    print "0.:map"
  }
}

{ main($0) }
