# Prints the plan file's document with one ticket changed: its state and
# its milestone, each when the argument for it is not empty. Loaded after
# plan_file.awk.
#
# Input: the document. Arguments "key", "state" and "milestone".

function main(line) {
  tree_line(line)
}

# Prints the tickets, the one with the key changed.
function print_tickets(__ticket, __count) {
  __count = 0

  for (__ticket = first_ticket(); __ticket != 0; __ticket = NODE_NEXT[__ticket]) {
    if (key_of(__ticket) == arg("key")) {
      print_updated(__ticket, __count)
    } else {
      print_node(__ticket, 1, __count)
    }
    __count++
  }
}

# Prints a ticket at an index with its state and its milestone as the
# arguments give them: each where the ticket has it, and at the end when
# it has none. An empty argument leaves the member as it is.
function print_updated(ticket, index_in_list, __member, __state_set, __milestone_set) {
  print_open(1, index_in_list, "map")
  __state_set = (arg("state") == "")
  __milestone_set = (arg("milestone") == "")

  for (__member = NODE_FIRST[ticket]; __member != 0; __member = NODE_NEXT[__member]) {
    if (NODE_KEY[__member] == wrap("state") && arg("state") != "") {
      print_str(2, "state", arg("state"))
      __state_set = 1
    } else if (NODE_KEY[__member] == wrap("milestone") && arg("milestone") != "") {
      print_str(2, "milestone", arg("milestone"))
      __milestone_set = 1
    } else {
      print_node(__member, 2, NODE_KEY[__member])
    }
  }

  if (!__state_set) {
    print_str(2, "state", arg("state"))
  }
  if (!__milestone_set) {
    print_str(2, "milestone", arg("milestone"))
  }
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  print_changed_document()
}

{ main($0) }
