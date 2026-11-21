# Prints the plan file's document with one ticket recorded among the
# blockers of another, once. Loaded after plan_file.awk and
# plan_blockers.awk.
#
# Input: the document. Arguments "blocker" and "blocked": the keys of the
# two tickets.

function main(line) {
  tree_line(line)
}

# Prints the tickets. The blocked ticket gets the blocker added to its
# blockers, each as a str, unless it has it already.
function print_tickets(__ticket, __count) {
  __count = 0

  for (__ticket = first_ticket(); __ticket != 0; __ticket = NODE_NEXT[__ticket]) {
    if (key_of(__ticket) == arg("blocked") && !is_blocked_by(__ticket, arg("blocker"))) {
      print_ticket_with(__ticket, __count, "blocked_by")
    } else {
      print_node(__ticket, 1, __count)
    }
    __count++
  }
}

# Prints the blockers of a ticket with the blocker added.
function print_changed(ticket, name) {
  print_blockers(ticket, "", arg("blocker"))
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
