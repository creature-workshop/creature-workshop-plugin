# Prints the areas whose names are among the names given, as they are.
#
# Input: the areas, and ahead of them, with --with, the names.

function main(line) {
  tree_line(line)
}

BEGIN {
  NAMES = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  for (name = NODE_FIRST[NAMES]; name != 0; name = NODE_NEXT[name]) {
    picked[text_of(name)] = 1
  }

  areas = 0
  for (area = NODE_FIRST[ROOT]; area != 0; area = NODE_NEXT[area]) {
    if (name_of(area) in picked) {
      print_node(area, 0, NODE_KEY[area])
      areas++
    }
  }

  if (areas == 0) {
    print "0.:map"
  }
}

{ main($0) }
