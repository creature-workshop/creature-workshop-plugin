# Prints the plan of the whole repository from the plans of every declared
# scope.
#
# Input:  {scopes, plans}
# Output: {scopes, states, milestones, tickets, edges}
#
# Each state, milestone and ticket gets its tracker's name under "tracker".
# The edges each tracker records are joined by the ones a ticket's
# description writes as "Blocked by <key>" or "Blocks <key>". A key is
# PREFIX-12, org/repo#12 or #12, it may name its tracker before a colon,
# and the keys of a line end at the first word that is not one. The edges
# are each listed once, in the order of the blocked key and then of the
# blocker.
#
# The tickets are in the order of their keys. A stub that another declared
# tracker has as a ticket is left out. A key that an edge names and no
# tracker has gets a stub.

function main(line) {
  tree_line(line)
}

# Reads every plan: its states and milestones for printing, its tickets,
# and the edges it records.
function read_plans(__plan, __tracker, __node) {
  for (__plan = NODE_FIRST[member(ROOT, "plans")]; __plan != 0; __plan = NODE_NEXT[__plan]) {
    __tracker = member(member(__plan, "scope"), "name")

    for (__node = NODE_FIRST[member(__plan, "states")]; __node != 0; __node = NODE_NEXT[__node]) {
      STATES++
      STATE[STATES] = __node
      STATE_TRACKER[STATES] = __tracker
    }
    for (__node = NODE_FIRST[member(__plan, "milestones")]; __node != 0; __node = NODE_NEXT[__node]) {
      MILESTONES++
      MILESTONE[MILESTONES] = __node
      MILESTONE_TRACKER[MILESTONES] = __tracker
    }
    for (__node = NODE_FIRST[member(__plan, "tickets")]; __node != 0; __node = NODE_NEXT[__node]) {
      TICKETS++
      TICKET[TICKETS] = __node
      TICKET_TRACKER[TICKETS] = __tracker
    }
    for (__node = NODE_FIRST[member(__plan, "edges")]; __node != 0; __node = NODE_NEXT[__node]) {
      note_edge(text_of(member(__node, "blocker")), text_of(member(__node, "blocked")))
    }
  }
}

# Whether a ticket is a stub.
function is_stub(ticket) {
  return text_of(member(ticket, "stub")) == "true"
}

# Keeps an edge once.
function note_edge(blocker, blocked) {
  if ((blocked, blocker) in EDGE_SEEN) {
    return
  }

  EDGE_SEEN[blocked, blocker] = 1
  EDGES++
  EDGE_BLOCKER[EDGES] = blocker
  EDGE_BLOCKED[EDGES] = blocked
}

# Reads the edges the descriptions of the tickets write, and notes the
# keys the tickets that are not stubs have.
function read_prose(__i, __key, __description) {
  for (__i = 1; __i <= TICKETS; __i++) {
    if (is_stub(TICKET[__i])) {
      continue
    }

    __key = text_of(member(TICKET[__i], "key"))
    HELD[__key] = 1
    __description = text_or(member(TICKET[__i], "description"), "")
    read_phrase(__description, "blocked by", __key, 1)
    read_phrase(__description, "blocks", __key, 0)
  }
}

# Reads every place a description writes a phrase, in any case, with a
# colon or without, and notes an edge for each key that follows it on the
# line. inward is 1 when the keys block the ticket, and 0 when the ticket
# blocks them.
function read_phrase(description, phrase, key, inward, __lowered, __from, __line) {
  __lowered = tolower(description)
  __from = 1

  while (match(substr(__lowered, __from), phrase ":? *[^\n]+")) {
    __line = substr(description, __from + RSTART - 1 + length(phrase), RLENGTH - length(phrase))
    __from = __from + RSTART - 1 + RLENGTH
    sub(/^:? */, "", __line)
    note_references(__line, key, inward)
  }
}

# Notes an edge for each key a line opens with, up to the first word that
# is not a key.
function note_references(line, key, inward, __words, __count, __i, __word) {
  __count = split(line, __words, /[ ,;]+/)

  for (__i = 1; __i <= __count; __i++) {
    __word = __words[__i]
    if (__word == "") {
      continue
    }

    sub(/^[A-Za-z0-9_-]+:/, "", __word)
    sub(/[.,;:]+$/, "", __word)
    if (__word !~ /^([A-Za-z][A-Za-z0-9_]*-[0-9]+|[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+#[0-9]+|#[0-9]+)$/) {
      return
    }

    if (inward) {
      note_edge(__word, key)
    } else {
      note_edge(key, __word)
    }
  }
}

# Whether edge a orders before edge b: by the blocked key, then by the
# blocker, as text.
function edge_orders_before(a, b) {
  if ((EDGE_BLOCKED[a] "") != (EDGE_BLOCKED[b] "")) {
    return (EDGE_BLOCKED[a] "") < (EDGE_BLOCKED[b] "")
  }

  return (EDGE_BLOCKER[a] "") < (EDGE_BLOCKER[b] "")
}

# Puts the edges in order in EDGE_ORDER[1..EDGES], by insertion.
function order_edges(__i, __place) {
  for (__i = 1; __i <= EDGES; __i++) {
    __place = __i
    while (__place > 1 && edge_orders_before(__i, EDGE_ORDER[__place - 1])) {
      EDGE_ORDER[__place] = EDGE_ORDER[__place - 1]
      __place--
    }
    EDGE_ORDER[__place] = __i
  }
}

# Chooses the tickets that are listed: every ticket that is not a stub,
# and every stub whose key no tracker has as a ticket, one for each key,
# the first that has it. Puts them in the order of their keys in
# LISTED[1..LISTED_COUNT].
function choose_tickets(__i, __key, __place) {
  LISTED_COUNT = 0

  for (__i = 1; __i <= TICKETS; __i++) {
    __key = text_of(member(TICKET[__i], "key"))
    if ((is_stub(TICKET[__i]) && (__key in HELD)) || (__key in LISTED_KEY)) {
      continue
    }

    LISTED_KEY[__key] = 1
    LISTED_COUNT++
    __place = LISTED_COUNT
    while (__place > 1 && (text_of(member(TICKET[LISTED[__place - 1]], "key")) "") > (__key "")) {
      LISTED[__place] = LISTED[__place - 1]
      __place--
    }
    LISTED[__place] = __i
  }
}

# Notes a key that an edge names and no listed ticket has, once, in
# UNKNOWN[1..UNKNOWNS] in the order of the keys.
function note_unknown(key, __place) {
  if ((key in LISTED_KEY) || (key in UNKNOWN_KEY)) {
    return
  }

  UNKNOWN_KEY[key] = 1
  UNKNOWNS++
  __place = UNKNOWNS
  while (__place > 1 && (UNKNOWN[__place - 1] "") > (key "")) {
    UNKNOWN[__place] = UNKNOWN[__place - 1]
    __place--
  }
  UNKNOWN[__place] = key
}

# Prints a node at an index of a list at depth 1 with a tracker's name
# under "tracker": where the node has a tracker already, and at the end
# when it has none.
function print_tagged(node, index_in_list, tracker, __member, __tagged) {
  print_open(1, index_in_list, "map")
  __tagged = 0

  for (__member = NODE_FIRST[node]; __member != 0; __member = NODE_NEXT[__member]) {
    if (NODE_KEY[__member] == wrap("tracker")) {
      print_node(tracker, 2, wrap("tracker"))
      __tagged = 1
    } else {
      print_node(__member, 2, NODE_KEY[__member])
    }
  }

  if (!__tagged) {
    print_node(tracker, 2, wrap("tracker"))
  }
}

# Prints the states and the milestones of every plan.
function print_states_and_milestones(__i) {
  print_open(0, wrap("states"), "list")
  for (__i = 1; __i <= STATES; __i++) {
    print_tagged(STATE[__i], __i - 1, STATE_TRACKER[__i])
  }

  print_open(0, wrap("milestones"), "list")
  for (__i = 1; __i <= MILESTONES; __i++) {
    print_tagged(MILESTONE[__i], __i - 1, MILESTONE_TRACKER[__i])
  }
}

# Prints the listed tickets, and then a stub for each unknown key.
function print_tickets(__i) {
  print_open(0, wrap("tickets"), "list")

  for (__i = 1; __i <= LISTED_COUNT; __i++) {
    print_tagged(TICKET[LISTED[__i]], __i - 1, TICKET_TRACKER[LISTED[__i]])
  }
  for (__i = 1; __i <= UNKNOWNS; __i++) {
    print_stub(UNKNOWN[__i], LISTED_COUNT + __i - 1)
  }
}

# Prints the stub of a key that no tracker has, at an index.
function print_stub(key, index_in_list) {
  print_open(1, index_in_list, "map")
  print_str(2, "id", key)
  print_str(2, "key", key)
  print_str(2, "title", key)
  print_open(2, wrap("state"), "map")
  print_str(3, "name", "todo")
  print_str(3, "type", "todo")
  print "2." wrap("estimate") ":null"
  print "2." wrap("priority") ":null"
  print "2." wrap("assignee") ":null"
  print "2." wrap("milestone") ":null"
  print "2." wrap("url") ":null"
  print_str(2, "description", "")
  print "2." wrap("stub") ":bool=true"
  print "2." wrap("tracker") ":null"
}

# Prints the edges in order, each {blocker, blocked}.
function print_edges(__i, __edge) {
  print_open(0, wrap("edges"), "list")

  for (__i = 1; __i <= EDGES; __i++) {
    __edge = EDGE_ORDER[__i]
    print_open(1, __i - 1, "map")
    print_str(2, "blocker", EDGE_BLOCKER[__edge])
    print_str(2, "blocked", EDGE_BLOCKED[__edge])
  }
}

BEGIN {
  ROOT = tree_open()
  STATES = 0
  MILESTONES = 0
  TICKETS = 0
  EDGES = 0
  UNKNOWNS = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  read_plans()
  read_prose()
  order_edges()
  choose_tickets()
  for (i = 1; i <= EDGES; i++) {
    note_unknown(EDGE_BLOCKER[EDGE_ORDER[i]])
    note_unknown(EDGE_BLOCKED[EDGE_ORDER[i]])
  }

  print_node(member(ROOT, "scopes"), 0, wrap("scopes"))
  print_states_and_milestones()
  print_tickets()
  print_edges()
}

{ main($0) }
