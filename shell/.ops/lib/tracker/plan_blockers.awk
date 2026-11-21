# Rewriting the blockers of one ticket of a plan file, for the programs
# that link, unlink and delete tickets. It holds functions alone. A program
# defines print_changed(ticket, name), which prints the changed member of
# the ticket at depth 2. Loaded after plan_file.awk.

# Prints a ticket at an index with one member changed: every other member
# as it is, and the member named printed by print_changed(ticket, name),
# which the program defines, where the ticket has it, and at the end when
# it has none.
function print_ticket_with(ticket, index_in_list, name, __member, __printed) {
  print_open(1, index_in_list, "map")
  __printed = 0

  for (__member = NODE_FIRST[ticket]; __member != 0; __member = NODE_NEXT[__member]) {
    if (NODE_KEY[__member] == wrap(name)) {
      print_changed(ticket, name)
      __printed = 1
    } else {
      print_node(__member, 2, NODE_KEY[__member])
    }
  }

  if (!__printed) {
    print_changed(ticket, name)
  }
}

# Prints the blockers of a ticket as a list of strs under "blocked_by" at
# depth 2, leaving out the one named, and adding the one named when add is
# 1 and it is not there yet.
function print_blockers(ticket, leave_out, add, __blocker, __count, __held) {
  print_open(2, wrap("blocked_by"), "list")

  __count = 0
  __held = 0
  for (__blocker = NODE_FIRST[member(ticket, "blocked_by")]; __blocker != 0; __blocker = NODE_NEXT[__blocker]) {
    if (leave_out != "" && text_of(__blocker) == leave_out) {
      continue
    }
    if (text_of(__blocker) == add) {
      __held = 1
    }
    print "3." __count ":str=" wrap(text_of(__blocker))
    __count++
  }

  if (add != "" && !__held) {
    print "3." __count ":str=" wrap(add)
  }
}

# Whether a ticket has the blocker named among its blockers.
function is_blocked_by(ticket, blocker, __node) {
  for (__node = NODE_FIRST[member(ticket, "blocked_by")]; __node != 0; __node = NODE_NEXT[__node]) {
    if (text_of(__node) == blocker) {
      return 1
    }
  }

  return 0
}
