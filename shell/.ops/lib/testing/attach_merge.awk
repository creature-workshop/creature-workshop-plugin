# Prints the areas with the test files discovery found joined to the tests
# each area declares. Loaded after testing.awk.
#
# Input: the areas, and ahead of them, with --with, the derived tests, a
#        map of area to a map of suite to files.
#
# Each area's tests become, for every suite, the files it declares and the
# derived files, in byte order and each once. A suite with no file is left
# out. The suites the area declares come first, in its order, and then the
# suites only discovery found.

function main(line) {
  tree_line(line)
}

# Prints one area with its tests merged: where the area has tests, and
# after its other fields when it has none.
function print_area(area, derived, __field, __printed) {
  print_open(0, NODE_KEY[area], "map")
  __printed = 0

  for (__field = NODE_FIRST[area]; __field != 0; __field = NODE_NEXT[__field]) {
    if (NODE_KEY[__field] == wrap("tests")) {
      print_merged_tests(normalized_tests(area), derived)
      __printed = 1
    } else {
      print_node(__field, 1, NODE_KEY[__field])
    }
  }

  if (!__printed) {
    print_merged_tests(0, derived)
  }
}

# Prints the merged tests of an area at depth 1.
function print_merged_tests(explicit, derived, __suite) {
  print_open(1, wrap("tests"), "map")

  for (__suite = NODE_FIRST[explicit]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    print_suite(NODE_KEY[__suite], __suite, child(derived, NODE_KEY[__suite]))
  }
  for (__suite = NODE_FIRST[derived]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    if (child(explicit, NODE_KEY[__suite]) == 0) {
      print_suite(NODE_KEY[__suite], 0, __suite)
    }
  }
}

# Prints one suite's files from both sides, in byte order and each once,
# and nothing when there is none.
function print_suite(key, explicit, derived, __file, __files, __count) {
  __count = 0
  for (__file = NODE_FIRST[explicit]; __file != 0; __file = NODE_NEXT[__file]) {
    __files[++__count] = text_of(__file)
  }
  for (__file = NODE_FIRST[derived]; __file != 0; __file = NODE_NEXT[__file]) {
    __files[++__count] = text_of(__file)
  }

  __count = unique_texts(__files, __count)
  if (__count > 0) {
    print_open(2, key, "list")
    print_texts(__files, __count, 2)
  }
}

BEGIN {
  DERIVED = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  areas = 0
  for (area = NODE_FIRST[ROOT]; area != 0; area = NODE_NEXT[area]) {
    print_area(area, child(DERIVED, NODE_KEY[area]))
    areas++
  }

  if (areas == 0) {
    print "0.:map"
  }
}

{ main($0) }
