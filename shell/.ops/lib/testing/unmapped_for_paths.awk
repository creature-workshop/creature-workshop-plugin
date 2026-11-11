# Prints the changed files that no area maps: no area's paths cover the
# file, and no area lists it among its tests. Loaded after testing.awk.
#
# Input: the areas, and ahead of them, with --with, the changed files.

function main(line) {
  tree_line(line)
}

# Whether any area maps a file.
function mapped(file, __area) {
  for (__area = NODE_FIRST[ROOT]; __area != 0; __area = NODE_NEXT[__area]) {
    if (covered_by(member(__area, "paths"), file) || in_tests(__area, file)) {
      return 1
    }
  }

  return 0
}

BEGIN {
  CHANGED = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  unmapped = 0
  for (file = NODE_FIRST[CHANGED]; file != 0; file = NODE_NEXT[file]) {
    if (!mapped(text_of(file))) {
      print_node(file, 0, unmapped)
      unmapped++
    }
  }

  if (unmapped == 0) {
    print "0.:list"
  }
}

{ main($0) }
