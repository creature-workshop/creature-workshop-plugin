# Prints the plan a plan file keeps, as the tracker kind's plan struct:
# {scope, states, milestones, tickets, edges}.
#
# Input: the plan file's document, and ahead of it, with --with and in
#        this order: the scope, the states of the scope, and the state a
#        ticket has when it names none.
#
# A key, a title, a name and a blocker are read as text, so a number
# written in the file is the str that spells it. A ticket that names a
# state the file does not have is refused, naming the state.

function main(line) {
  tree_line(line)
}

# The text of a node, and the word null for no node.
function as_text(node) {
  return (node == 0) ? "null" : text_of(node)
}

# What the text of a node writes after a key: a str, and a null for a node
# that is missing or a null.
function text_or_null(node) {
  return is_present(node) ? "str=" wrap(text_of(node)) : "null"
}

# The state of the scope that has a name, refused when the scope has none
# of that name.
function state_named(name, __state, __names) {
  __names = ""

  for (__state = NODE_FIRST[STATES]; __state != 0; __state = NODE_NEXT[__state]) {
    if (NODE_TYPE[member(__state, "name")] == "str" && text_of(member(__state, "name")) == name) {
      return __state
    }
    __names = __names (__names == "" ? "" : ", ") text_or(member(__state, "name"), "")
  }

  refuse("no state named " name " in the plan file; its states: " __names)
}

# Prints the milestones, each {id, name, target}. A milestone with no name
# is named by its id.
function print_milestones(__milestone, __count, __name) {
  print_open(0, wrap("milestones"), "list")

  __count = 0
  for (__milestone = NODE_FIRST[member(ROOT, "milestones")]; __milestone != 0; __milestone = NODE_NEXT[__milestone]) {
    __name = is_present(member(__milestone, "name")) ? member(__milestone, "name") : member(__milestone, "id")
    print_open(1, __count, "map")
    print_str(2, "id", as_text(member(__milestone, "id")))
    print_str(2, "name", as_text(__name))
    print "2." wrap("target") ":" text_or_null(member(__milestone, "target"))
    __count++
  }
}

# Prints the tickets, each as the tracker kind's ticket.
function print_tickets(__ticket, __count) {
  print_open(0, wrap("tickets"), "list")

  __count = 0
  for (__ticket = NODE_FIRST[member(ROOT, "tickets")]; __ticket != 0; __ticket = NODE_NEXT[__ticket]) {
    print_open(1, __count, "map")
    print_ticket(__ticket)
    __count++
  }
}

# Prints the members of one ticket at depth 2.
function print_ticket(ticket, __state) {
  __state = is_present(member(ticket, "state")) ? state_named(text_of(member(ticket, "state"))) : DEFAULT

  print_str(2, "id", as_text(member(ticket, "key")))
  print_str(2, "key", as_text(member(ticket, "key")))
  print_str(2, "title", text_or(member(ticket, "title"), ""))
  print_node(__state, 2, wrap("state"))
  print_node(member(ticket, "estimate"), 2, wrap("estimate"))
  print_node(member(ticket, "priority"), 2, wrap("priority"))
  print "2." wrap("assignee") ":" text_or_null(member(ticket, "assignee"))
  print "2." wrap("milestone") ":" text_or_null(member(ticket, "milestone"))
  print "2." wrap("lane") ":" text_or_null(member(ticket, "lane"))
  print "2." wrap("url") ":null"
  print_str(2, "description", text_or(member(ticket, "description"), ""))
  print "2." wrap("stub") ":bool=false"
}

# Prints the edges, one {blocker, blocked} for each blocker a ticket
# lists.
function print_edges(__ticket, __blocker, __count) {
  print_open(0, wrap("edges"), "list")

  __count = 0
  for (__ticket = NODE_FIRST[member(ROOT, "tickets")]; __ticket != 0; __ticket = NODE_NEXT[__ticket]) {
    for (__blocker = NODE_FIRST[member(__ticket, "blocked_by")]; __blocker != 0; __blocker = NODE_NEXT[__blocker]) {
      print_open(1, __count, "map")
      print_str(2, "blocker", as_text(__blocker))
      print_str(2, "blocked", as_text(member(__ticket, "key")))
      __count++
    }
  }
}

BEGIN {
  SCOPE = tree_ahead()
  STATES = tree_ahead()
  DEFAULT = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  print_node(SCOPE, 0, wrap("scope"))
  print_node(STATES, 0, wrap("states"))
  print_milestones()
  print_tickets()
  print_edges()
}

{ main($0) }
