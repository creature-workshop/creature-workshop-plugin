# Prints a dependencies section with a new imports map.
#
# Input: {section, imports}: the section as the lock has it, and the map to
#        set under imports.
#
# The git map of a lock written before the imports map existed is left
# out, since the imports and the tools record the same trees.

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

  placed = 0
  for (field = NODE_FIRST[member(ROOT, "section")]; field != 0; field = NODE_NEXT[field]) {
    if (NODE_KEY[field] == wrap("imports")) {
      print_node(member(ROOT, "imports"), 0, wrap("imports"))
      placed = 1
    } else if (NODE_KEY[field] != wrap("git")) {
      print_node(field, 0, NODE_KEY[field])
    }
  }

  if (!placed) {
    print_node(member(ROOT, "imports"), 0, wrap("imports"))
  }
}

{ main($0) }
