# Prints the flat set of areas a testing config declares, as a map keyed by
# dotted area name: "engine.parser" is the area parser under the area
# engine. An area that the config writes as a text, "name": "path", is the
# area whose source is that path. A parent is printed before its children.
#
# Each area has:
#   paths       its source as a list of one, or the empty list for an area
#               with no source
#   tests       its own tests block, or the empty map
#   inert       true when the nearest ancestor that declares a tests block,
#               the area itself among them, declares it empty: the area is
#               no-code by declaration, so selecting nothing for it is right
#   full_suite  what the nearest ancestor that sets it sets, the area
#               itself among them, and false when none does
#   coverage    the config's coverage laid under each ancestor's own, from
#               the root down to the area, so the nearest wins field by
#               field; left out when no field is set
#
# Input: the testing config, {areas, coverage}.

function main(line) {
  tree_line(line)
}

# Prints the areas under a node, each with the dotted name its ancestors
# give it, and then its own children. depth is how many ancestors an area
# of this node has.
function print_areas(areas, prefix, depth, __area, __name) {
  for (__area = NODE_FIRST[areas]; __area != 0; __area = NODE_NEXT[__area]) {
    __name = (prefix == "") ? name_of(__area) : prefix "." name_of(__area)
    ANCESTOR[depth + 1] = __area
    print_area(__area, __name, depth + 1)
    AREAS++
    print_areas(member(__area, "areas"), __name, depth + 1)
  }
}

# Prints one area. Its ancestors are ANCESTOR[1..depth], the area itself
# the last of them.
function print_area(area, name, depth, __source) {
  __source = (NODE_TYPE[area] == "str") ? area : member(area, "source")

  print_open(0, wrap(name), "map")
  print_open(1, wrap("paths"), "list")
  if (text_or(__source, "") != "") {
    print_node(__source, 2, 0)
  }
  if (is_present(member(area, "tests"))) {
    print_node(member(area, "tests"), 1, wrap("tests"))
  } else {
    print_open(1, wrap("tests"), "map")
  }
  print "1." wrap("inert") ":bool=" inherited_inert(depth)
  print "1." wrap("full_suite") ":" inherited_full_suite(depth)
  print_coverage(depth)
}

# The word true when the nearest ancestor that has a tests block has an
# empty one, and the word false otherwise.
function inherited_inert(depth, __i, __declared) {
  __declared = 0

  for (__i = 1; __i <= depth; __i++) {
    if (member(ANCESTOR[__i], "tests") != 0) {
      __declared = member(ANCESTOR[__i], "tests")
    }
  }

  return (__declared != 0 && NODE_TYPE[__declared] == "map" && NODE_COUNT[__declared] == 0) ? "true" : "false"
}

# What the full_suite of the nearest ancestor that sets it writes after a
# key, and a false when none sets it.
function inherited_full_suite(depth, __i, __own) {
  __own = 0

  for (__i = 1; __i <= depth; __i++) {
    if (member(ANCESTOR[__i], "full_suite") != 0) {
      __own = member(ANCESTOR[__i], "full_suite")
    }
  }

  return is_present(__own) ? written(__own) : "bool=false"
}

# Prints the coverage of an area: the config's fields, each replaced by
# the nearest ancestor that sets it. Prints nothing when no field is set.
function print_coverage(depth, __i, __field, __fields, __name, __n) {
  __fields = 0
  lay_coverage(member(ROOT, "coverage"))
  for (__i = 1; __i <= depth; __i++) {
    lay_coverage(member(ANCESTOR[__i], "coverage"))
  }

  if (COVERAGE_FIELDS == 0) {
    return
  }

  print_open(1, wrap("coverage"), "map")
  for (__n = 1; __n <= COVERAGE_FIELDS; __n++) {
    __name = COVERAGE_NAME[__n]
    print_node(COVERAGE_OF[__name], 2, __name)
    delete COVERAGE_OF[__name]
  }
  COVERAGE_FIELDS = 0
}

# Lays the fields of one coverage block over the fields laid so far: a new
# field after the others, and a field laid before in its place.
function lay_coverage(coverage, __field) {
  for (__field = NODE_FIRST[coverage]; __field != 0; __field = NODE_NEXT[__field]) {
    if (!(NODE_KEY[__field] in COVERAGE_OF)) {
      COVERAGE_FIELDS++
      COVERAGE_NAME[COVERAGE_FIELDS] = NODE_KEY[__field]
    }
    COVERAGE_OF[NODE_KEY[__field]] = __field
  }
}

BEGIN {
  ROOT = tree_open()
  AREAS = 0
  COVERAGE_FIELDS = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  print_areas(member(ROOT, "areas"), "", 0)
  if (AREAS == 0) {
    print "0.:map"
  }
}

{ main($0) }
