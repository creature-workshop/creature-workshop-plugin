# Prints the plan of a Linear scope, from the team, the project and the
# issues the API answered with. Loaded after tracker_issue.awk.
#
# Input:  {scope, team, project, issues}
# Output: {scope, states, milestones, tickets, edges}
#
# The tickets are the issues of the scope, and after them a stub for each
# issue outside the scope that blocks one of them or is blocked by one, in
# the order of their identifiers. The edges are {blocker, blocked}, each
# once, in the order of the blocked identifier and then of the blocker.

function main(line) {
  tree_line(line)
}

# Prints the milestones of the project by their sort order, each
# {id, name, target}.
function print_milestones(__i) {
  print_open(0, wrap("milestones"), "list")
  order_children(member(member(member(ROOT, "project"), "projectMilestones"), "nodes"), "sortOrder")

  for (__i = 1; __i <= ORDERED_COUNT; __i++) {
    print_open(1, __i - 1, "map")
    print_node(member(ORDERED[__i], "id"), 2, wrap("id"))
    print_node(member(ORDERED[__i], "name"), 2, wrap("name"))
    print_node(member(ORDERED[__i], "targetDate"), 2, wrap("target"))
  }
}

# Reads the blocks relations of every issue: an edge for each, and the
# issue at the other end when it is outside the scope.
function read_relations(__issue, __relation, __key) {
  for (__issue = NODE_FIRST[ISSUES]; __issue != 0; __issue = NODE_NEXT[__issue]) {
    IN_SCOPE[text_of(member(__issue, "identifier"))] = 1
  }

  for (__issue = NODE_FIRST[ISSUES]; __issue != 0; __issue = NODE_NEXT[__issue]) {
    __key = text_of(member(__issue, "identifier"))
    for (__relation = NODE_FIRST[member(member(__issue, "relations"), "nodes")]; __relation != 0; __relation = NODE_NEXT[__relation]) {
      note_relation(__relation, __key, member(__relation, "relatedIssue"), 1)
    }
    for (__relation = NODE_FIRST[member(member(__issue, "inverseRelations"), "nodes")]; __relation != 0; __relation = NODE_NEXT[__relation]) {
      note_relation(__relation, __key, member(__relation, "issue"), 0)
    }
  }
}

# Notes one relation of the issue with the key given, when it is a blocks
# relation: the edge it makes, and the other issue when it is outside the
# scope. outward is 1 when the issue is the blocker and 0 when it is
# blocked.
function note_relation(relation, key, other, outward, __other_key) {
  if (text_of(member(relation, "type")) != "blocks") {
    return
  }

  __other_key = text_of(member(other, "identifier"))
  if (outward) {
    note_edge(key, __other_key)
  } else {
    note_edge(__other_key, key)
  }

  if (!(__other_key in IN_SCOPE) && !(__other_key in OUTSIDE)) {
    OUTSIDE[__other_key] = other
    OUTSIDE_COUNT++
    OUTSIDE_KEY[OUTSIDE_COUNT] = __other_key
  }
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

# Whether edge a orders before edge b: by the blocked identifier, then by
# the blocker, as text.
function edge_orders_before(a, b) {
  if ((EDGE_BLOCKED[a] "") != (EDGE_BLOCKED[b] "")) {
    return (EDGE_BLOCKED[a] "") < (EDGE_BLOCKED[b] "")
  }

  return (EDGE_BLOCKER[a] "") < (EDGE_BLOCKER[b] "")
}

# Prints the edges in order, each {blocker, blocked}.
function print_edges(__i, __place, __edge) {
  for (__i = 1; __i <= EDGES; __i++) {
    __place = __i
    while (__place > 1 && edge_orders_before(__i, EDGE_ORDER[__place - 1])) {
      EDGE_ORDER[__place] = EDGE_ORDER[__place - 1]
      __place--
    }
    EDGE_ORDER[__place] = __i
  }

  print_open(0, wrap("edges"), "list")
  for (__i = 1; __i <= EDGES; __i++) {
    __edge = EDGE_ORDER[__i]
    print_open(1, __i - 1, "map")
    print_str(2, "blocker", EDGE_BLOCKER[__edge])
    print_str(2, "blocked", EDGE_BLOCKED[__edge])
  }
}

# Puts the identifiers of the issues outside the scope in order, as text.
function order_outside(__i, __place, __key) {
  for (__i = 2; __i <= OUTSIDE_COUNT; __i++) {
    __key = OUTSIDE_KEY[__i]
    __place = __i
    while (__place > 1 && (OUTSIDE_KEY[__place - 1] "") > (__key "")) {
      OUTSIDE_KEY[__place] = OUTSIDE_KEY[__place - 1]
      __place--
    }
    OUTSIDE_KEY[__place] = __key
  }
}

# Prints the tickets: the issues of the scope, then a stub for each issue
# outside it.
function print_tickets(__issue, __tickets, __i) {
  print_open(0, wrap("tickets"), "list")

  __tickets = 0
  for (__issue = NODE_FIRST[ISSUES]; __issue != 0; __issue = NODE_NEXT[__issue]) {
    print_open(1, __tickets, "map")
    print_ticket(__issue, 2, "false")
    __tickets++
  }

  order_outside()
  for (__i = 1; __i <= OUTSIDE_COUNT; __i++) {
    print_open(1, __tickets, "map")
    print_ticket(OUTSIDE[OUTSIDE_KEY[__i]], 2, "true")
    __tickets++
  }
}

BEGIN {
  ROOT = tree_open()
  EDGES = 0
  OUTSIDE_COUNT = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  ISSUES = member(ROOT, "issues")
  read_relations()
  print_node(member(ROOT, "scope"), 0, wrap("scope"))
  print_states_of_team(member(ROOT, "team"), 0, wrap("states"))
  print_milestones()
  print_tickets()
  print_edges()
}

{ main($0) }
