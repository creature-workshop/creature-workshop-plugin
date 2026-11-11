# Prints the selections as the run's record keeps them: for each selector
# its id, its confidence, its mode, the files it claimed and the tests it
# selected, which is the empty map for a selector that selected none.
#
# Input: the selections, a list of {id, confidence, mode, tests, claimed,
#        unclaimed}.

function main(line) {
  tree_line(line)
}

# Prints one selection as element n of the list.
function print_attribution(selection, n) {
  print_open(0, n, "map")
  print_node(member(selection, "id"), 1, wrap("id"))
  print_node(member(selection, "confidence"), 1, wrap("confidence"))
  print_node(member(selection, "mode"), 1, wrap("mode"))
  print_node(member(selection, "claimed"), 1, wrap("claimed"))

  if (is_present(member(selection, "tests"))) {
    print_node(member(selection, "tests"), 1, wrap("tests"))
  } else {
    print_open(1, wrap("tests"), "map")
  }
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  printed = 0
  for (selection = NODE_FIRST[ROOT]; selection != 0; selection = NODE_NEXT[selection]) {
    print_attribution(selection, printed++)
  }
  if (printed == 0) {
    print "0.:list"
  }
}

{ main($0) }
