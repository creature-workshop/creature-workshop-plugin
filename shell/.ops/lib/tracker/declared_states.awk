# Prints the states of every declared scope as one list, each with its
# tracker's name under "tracker".
#
# Input: [{scope, states}]

function main(line) {
  tree_line(line)
}

# Prints one state at an index with the tracker's name: where the state
# has a tracker already, and at the end when it has none.
function print_tagged(state, index_in_list, tracker, __member, __tagged) {
  print_open(0, index_in_list, "map")
  __tagged = 0

  for (__member = NODE_FIRST[state]; __member != 0; __member = NODE_NEXT[__member]) {
    if (NODE_KEY[__member] == wrap("tracker")) {
      print_node(tracker, 1, wrap("tracker"))
      __tagged = 1
    } else {
      print_node(__member, 1, NODE_KEY[__member])
    }
  }

  if (!__tagged) {
    print_node(tracker, 1, wrap("tracker"))
  }
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  states = 0
  for (declared = NODE_FIRST[ROOT]; declared != 0; declared = NODE_NEXT[declared]) {
    tracker = member(member(declared, "scope"), "name")
    for (state = NODE_FIRST[member(declared, "states")]; state != 0; state = NODE_NEXT[state]) {
      print_tagged(state, states, tracker)
      states++
    }
  }

  if (states == 0) {
    print "0.:list"
  }
}

{ main($0) }
