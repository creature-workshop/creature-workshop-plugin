# Prints the areas with the tests of every area that imports an area joined
# to that area's own, so a change to a module runs the tests of whatever
# depends on it while the config names only a module's own tests. Loaded
# after testing.awk.
#
# Input: the areas with each area's own tests attached, and ahead of them,
#        with --with, the file edges of the import graph, each {from, to}.
#
# An area's importers are every area that reaches it over the area edges,
# however many areas away. Each area's tests gain, suite by suite, the
# tests of its importers, and importer_tests counts the files that added.
# A suite that gained files is in byte order with each file once. An area
# that runs the full suite is left as it is: a change there runs
# everything already.

function main(line) {
  tree_line(line)
}

# Starts the tests of one area from its own: SUITE[1..SUITES] are the
# suites in order, FILES_OF[suite] the files a suite gained with a newline
# after each, and OWN_OF[suite] the area's own node for the suite.
function start_tests(own, __suite, __name) {
  for (__name in FILES_OF) {
    delete FILES_OF[__name]
    delete OWN_OF[__name]
    delete TOUCHED[__name]
  }
  SUITES = 0
  OWN_TOTAL = 0

  for (__suite = NODE_FIRST[own]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    __name = NODE_KEY[__suite]
    SUITES++
    SUITE[SUITES] = __name
    OWN_OF[__name] = __suite
    FILES_OF[__name] = joined_files(__suite)
    OWN_TOTAL += NODE_COUNT[__suite]
  }
}

# The files under a node, with a newline after each.
function joined_files(suite, __file, __joined) {
  __joined = ""
  for (__file = NODE_FIRST[suite]; __file != 0; __file = NODE_NEXT[__file]) {
    __joined = __joined text_of(__file) "\n"
  }

  return __joined
}

# Joins the tests of one importer to the tests so far.
function join_tests(other, __suite, __name) {
  for (__suite = NODE_FIRST[other]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    __name = NODE_KEY[__suite]
    if (!(__name in FILES_OF)) {
      SUITES++
      SUITE[SUITES] = __name
    }
    FILES_OF[__name] = FILES_OF[__name] joined_files(__suite)
    TOUCHED[__name] = 1
  }
}

# Sets TOTAL to how many files the tests so far hold, a suite that gained
# files counted with each file once.
function count_tests(__i, __name, __files) {
  TOTAL = 0

  for (__i = 1; __i <= SUITES; __i++) {
    __name = SUITE[__i]
    if (__name in TOUCHED) {
      TOTAL += unique_texts(__files, split(FILES_OF[__name], __files, "\n") - 1)
    } else {
      TOTAL += NODE_COUNT[OWN_OF[__name]]
    }
  }
}

# Prints the tests so far at depth 1. A suite that gained nothing is
# printed as the area has it.
function print_tests(__i, __name, __files, __count) {
  print_open(1, wrap("tests"), "map")

  for (__i = 1; __i <= SUITES; __i++) {
    __name = SUITE[__i]
    if (!(__name in TOUCHED)) {
      print_node(OWN_OF[__name], 2, __name)
      continue
    }

    __count = unique_texts(__files, split(FILES_OF[__name], __files, "\n") - 1)
    print_open(2, __name, "list")
    print_texts(__files, __count, 2)
  }
}

# Joins the tests of every importer of an area, unless the area runs the
# full suite.
function join_importers(area, __seen, __reached, __count, __i, __full) {
  __full = member(area, "full_suite")
  if (is_present(__full) && text_of(__full) != "false") {
    return
  }

  __seen[1] = name_of(area)
  __count = reach(__seen, 1, __reached)
  for (__i = 1; __i <= __count; __i++) {
    if (__reached[__i] != name_of(area)) {
      join_tests(normalized_tests(member(ROOT, __reached[__i])))
    }
  }
}

# Prints one area with its tests and the count of the files its importers
# added: each where the area has the field, and after its other fields
# when it has none.
function print_area(area, __field, __has_tests, __has_count) {
  print_open(0, NODE_KEY[area], "map")
  start_tests(normalized_tests(area))
  join_importers(area)
  count_tests()
  __has_tests = 0
  __has_count = 0

  for (__field = NODE_FIRST[area]; __field != 0; __field = NODE_NEXT[__field]) {
    if (NODE_KEY[__field] == wrap("tests")) {
      print_tests()
      __has_tests = 1
    } else if (NODE_KEY[__field] == wrap("importer_tests")) {
      print "1." wrap("importer_tests") ":int=" (TOTAL - OWN_TOTAL)
      __has_count = 1
    } else {
      print_node(__field, 1, NODE_KEY[__field])
    }
  }

  if (!__has_tests) {
    print_tests()
  }
  if (!__has_count) {
    print "1." wrap("importer_tests") ":int=" (TOTAL - OWN_TOTAL)
  }
}

BEGIN {
  EDGES = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  read_area_edges(ROOT, EDGES)
  areas = 0
  for (area = NODE_FIRST[ROOT]; area != 0; area = NODE_NEXT[area]) {
    print_area(area)
    areas++
  }

  if (areas == 0) {
    print "0.:map"
  }
}

{ main($0) }
