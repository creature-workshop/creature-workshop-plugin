# Prints the plan file's document with a ticket added after the others.
# The members of the ticket that are empty or null are left out. Loaded
# after plan_file.awk.
#
# Input: the document, and ahead of it, with --with, the ticket.

function main(line) {
  tree_line(line)
}

# Prints the tickets of the document and then the new one.
function print_tickets(__ticket, __count, __member) {
  __count = 0
  for (__ticket = first_ticket(); __ticket != 0; __ticket = NODE_NEXT[__ticket]) {
    print_node(__ticket, 1, __count)
    __count++
  }

  print_open(1, __count, "map")
  for (__member = NODE_FIRST[TICKET]; __member != 0; __member = NODE_NEXT[__member]) {
    if (is_present(__member) && written(__member) != "str=\"\"") {
      print_node(__member, 2, NODE_KEY[__member])
    }
  }
}

BEGIN {
  TICKET = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  print_changed_document()
}

{ main($0) }
