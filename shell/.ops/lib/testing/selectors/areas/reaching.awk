# Prints the names of the out-of-tree suites that a change selects whole,
# in byte order. A suite that declares the areas it depends on is selected
# when a changed file is under one of them, or under an area nested in
# one. A suite that declares none is selected when any impacted area is
# code, that is, not inert. Loaded after testing.awk.
#
# Input: the effective suites, {<suite>: {reach, depends_on}}, and ahead
#        of them, with --with and in this order: the dotted names of the
#        areas that the changed files are under, and the flat area map,
#        {<name>: {inert}}.
#
#   ["e2e"]

function main(line) {
  tree_line(line)
}

# Whether a suite's tests reach outside their own process tree.
function is_out_of_tree(suite) {
  return text_of(member(suite, "reach")) == "out_of_tree"
}

# Whether a change selects an out-of-tree suite whole.
function is_reached(suite, __depends_on) {
  __depends_on = member(suite, "depends_on")
  if (NODE_COUNT[__depends_on] == 0) {
    return any_code_impacted()
  }

  return depends_on_impacted(__depends_on)
}

# Whether any impacted area is code: one that is not marked inert.
function any_code_impacted(__name, __inert) {
  for (__name = NODE_FIRST[IMPACTED]; __name != 0; __name = NODE_NEXT[__name]) {
    __inert = member(member(AREAS, text_of(__name)), "inert")
    if (!is_present(__inert) || text_of(__inert) == "false") {
      return 1
    }
  }

  return 0
}

# Whether any impacted area is one of the areas given, or nested in one.
function depends_on_impacted(depends_on, __dependency, __name) {
  for (__dependency = NODE_FIRST[depends_on]; __dependency != 0; __dependency = NODE_NEXT[__dependency]) {
    for (__name = NODE_FIRST[IMPACTED]; __name != 0; __name = NODE_NEXT[__name]) {
      if (is_under(text_of(__dependency), text_of(__name))) {
        return 1
      }
    }
  }

  return 0
}

# Whether a dotted area name is another area's name or nested in it:
# lib.git is under lib.
function is_under(area, name) {
  return name == area || index(name, area ".") == 1
}

BEGIN {
  IMPACTED = tree_ahead()
  AREAS = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  reached = 0
  for (suite = NODE_FIRST[ROOT]; suite != 0; suite = NODE_NEXT[suite]) {
    if (is_out_of_tree(suite) && is_reached(suite)) {
      names[++reached] = name_of(suite)
    }
  }

  if (reached == 0) {
    print "0.:list"
  }
  sort_texts(names, reached)
  print_texts(names, reached, -1)
}

{ main($0) }
