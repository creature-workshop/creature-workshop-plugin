# Prints the plan file's document with one ticket taken out of the blockers
# of another. Loaded after plan_file.awk and plan_blockers.awk.
#
# Input: the document. Arguments "blocker" and "blocked": the keys of the
# two tickets.

function main(line) {
  tree_line(line)
}

# Prints the tickets. The blocked ticket lists its blockers without the
# blocker, each as a str.
function print_tickets(__ticket, __count) {
  __count = 0

  for (__ticket = first_ticket(); __ticket != 0; __ticket = NODE_NEXT[__ticket]) {
    if (key_of(__ticket) == arg("blocked")) {
      print_ticket_with(__ticket, __count, "blocked_by")
    } else {
      print_node(__ticket, 1, __count)
    }
    __count++
  }
}

# Prints the blockers of a ticket without the blocker.
function print_changed(ticket, name) {
  print_blockers(ticket, arg("blocker"), "")
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
