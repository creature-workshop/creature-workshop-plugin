# Prints the selection so far with one suite's derived test files folded
# in: each area's files for the suite joined to the ones the selection has,
# in byte order and each once. An area with no derived file is left as it
# is. Loaded after testing.awk.
#
# Input: the selection, a map of area to a map of suite to files, and
#        ahead of it, with --with, the derived files, a map of area to
#        files. Argument "suite": the suite.

function main(line) {
  tree_line(line)
}

# Prints one area of the selection with the derived files of the suite
# joined to its own: where the area has the suite, and after its other
# suites when it has none.
function print_folded(area, derived, depth, __suite, __printed) {
  __printed = 0

  for (__suite = NODE_FIRST[area]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    if (name_of(__suite) == arg("suite")) {
      print_joined(__suite, derived, depth)
      __printed = 1
    } else {
      print_node(__suite, depth, NODE_KEY[__suite])
    }
  }

  if (!__printed) {
    print_joined(0, derived, depth)
  }
}

# Prints the suite's files: the selection's own and the derived ones, in
# byte order and each once.
function print_joined(own, derived, depth, __file, __files, __count) {
  __count = 0
  for (__file = NODE_FIRST[own]; __file != 0; __file = NODE_NEXT[__file]) {
    __files[++__count] = text_of(__file)
  }
  for (__file = NODE_FIRST[derived]; __file != 0; __file = NODE_NEXT[__file]) {
    __files[++__count] = text_of(__file)
  }

  print_open(depth, wrap(arg("suite")), "list")
  print_texts(__files, unique_texts(__files, __count), depth)
}

BEGIN {
  DERIVED = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  printed = 0
  for (area = NODE_FIRST[ROOT]; area != 0; area = NODE_NEXT[area]) {
    derived = member(DERIVED, name_of(area))
    if (NODE_COUNT[derived] > 0) {
      print_open(0, NODE_KEY[area], "map")
      print_folded(area, derived, 1)
      FOLDED[name_of(area)] = 1
    } else {
      print_node(area, 0, NODE_KEY[area])
    }
    printed++
  }

  for (derived = NODE_FIRST[DERIVED]; derived != 0; derived = NODE_NEXT[derived]) {
    if (NODE_COUNT[derived] > 0 && !(name_of(derived) in FOLDED) && member(ROOT, name_of(derived)) == 0) {
      print_open(0, NODE_KEY[derived], "map")
      print_joined(0, derived, 1)
      printed++
    }
  }

  if (printed == 0) {
    print "0.:map"
  }
}

{ main($0) }
