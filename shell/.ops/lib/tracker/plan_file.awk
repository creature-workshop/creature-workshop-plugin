# Rewriting the document of a plan file, for the programs that change its
# tickets. It holds functions alone. A program defines print_tickets(),
# which prints the tickets of the changed document as the elements of a
# list at depth 1. Loaded after tree.awk.

# Prints the document with its tickets as the program prints them: every
# other member as it is, the tickets where the document has them, and at
# the end when it has none.
function print_changed_document(__member, __printed) {
  __printed = 0

  for (__member = NODE_FIRST[ROOT]; __member != 0; __member = NODE_NEXT[__member]) {
    if (NODE_KEY[__member] == wrap("tickets")) {
      print_open(0, wrap("tickets"), "list")
      print_tickets()
      __printed = 1
    } else {
      print_node(__member, 0, NODE_KEY[__member])
    }
  }

  if (!__printed) {
    print_open(0, wrap("tickets"), "list")
    print_tickets()
  }
}

# The first ticket of the document, and no node when it has none.
function first_ticket() {
  return NODE_FIRST[member(ROOT, "tickets")]
}

# The key of a ticket as text, a number among them.
function key_of(ticket) {
  return text_of(member(ticket, "key"))
}
