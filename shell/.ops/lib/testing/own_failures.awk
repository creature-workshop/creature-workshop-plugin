# Prints each list of the input without the elements the target has under
# the same key.
#
# Input: a map of key to a list, and ahead of it, with --with, the target,
#        a map of key to a list.

function main(line) {
  tree_line(line)
}

# Prints one list without the elements the target's list has.
function print_own(list, target, __element, __held, __count) {
  for (__element = NODE_FIRST[target]; __element != 0; __element = NODE_NEXT[__element]) {
    __held[written(__element)] = 1
  }

  print_open(0, NODE_KEY[list], "list")
  __count = 0
  for (__element = NODE_FIRST[list]; __element != 0; __element = NODE_NEXT[__element]) {
    if (!(written(__element) in __held)) {
      print_node(__element, 1, __count)
      __count++
    }
  }
}

BEGIN {
  TARGET = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  lists = 0
  for (list = NODE_FIRST[ROOT]; list != 0; list = NODE_NEXT[list]) {
    print_own(list, member(TARGET, name_of(list)))
    lists++
  }

  if (lists == 0) {
    print "0.:map"
  }
}

{ main($0) }
