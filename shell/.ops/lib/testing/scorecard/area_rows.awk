# Prints one row of the scorecard for each area: its name, its source
# paths, how many tests it has under each suite, the total over the
# suites, whether it is declared inert, how many of its tests its
# importers brought, and whether it runs the full suite. Loaded after
# testing.awk.
#
# Input: the attached areas, {<dotted name>: {paths, tests, inert,
#        full_suite, importer_tests}}.
#
#   {name: "lib.git", paths: ["lib/git"], tests: {unit: 3}, total: 3,
#    inert: false, importer_tests: 1, full_suite: false}

function main(line) {
  tree_line(line)
}

# Prints a member of an area under the same name at depth 1, and a
# fallback, written as a line writes it, when the area has none or has a
# false.
function print_or(area, name, fallback, __node) {
  __node = member(area, name)
  if (is_truthy(__node)) {
    print_node(__node, 1, wrap(name))
  } else {
    print "1." wrap(name) ":" fallback
  }
}

# Prints the row of one area as element n of the list.
function print_row(area, n, __tests, __suite, __total) {
  __tests = normalized_tests(area)
  __total = 0

  print_open(0, n, "map")
  print_str(1, "name", name_of(area))
  print_or(area, "paths", "list")
  print_open(1, wrap("tests"), "map")
  for (__suite = NODE_FIRST[__tests]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    print "2." NODE_KEY[__suite] ":int=" NODE_COUNT[__suite]
    __total += NODE_COUNT[__suite]
  }
  print "1." wrap("total") ":int=" __total
  print_or(area, "inert", "bool=false")
  print_or(area, "importer_tests", "int=0")
  print_or(area, "full_suite", "bool=false")
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  printed = 0
  for (area = NODE_FIRST[ROOT]; area != 0; area = NODE_NEXT[area]) {
    print_row(area, printed++)
  }
  if (printed == 0) {
    print "0.:list"
  }
}

{ main($0) }
