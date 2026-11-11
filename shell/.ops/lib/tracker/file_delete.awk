# Prints the plan file's document without one ticket, and with that
# ticket's key taken out of the blockers of every other ticket. Loaded
# after plan_file.awk and plan_blockers.awk.
#
# Input: the document. Argument "key": the key of the ticket.

function main(line) {
  tree_line(line)
}

# Prints the tickets that are kept. A ticket that lists blockers lists them
# without the key, each as a str.
function print_tickets(__ticket, __count) {
  __count = 0

  for (__ticket = first_ticket(); __ticket != 0; __ticket = NODE_NEXT[__ticket]) {
    if (key_of(__ticket) == arg("key")) {
      continue
    }

    if (is_present(member(__ticket, "blocked_by"))) {
      print_ticket_with(__ticket, __count, "blocked_by")
    } else {
      print_node(__ticket, 1, __count)
    }
    __count++
  }
}

# Prints the blockers of a ticket without the key.
function print_changed(ticket, name) {
  print_blockers(ticket, arg("key"), "")
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
