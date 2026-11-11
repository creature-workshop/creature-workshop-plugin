# What a Linear issue record is as a ticket of the plan, and a workflow
# state as a state of it, for the programs that read Linear's answers. It
# holds functions alone. Loaded after tree.awk.

# What the type of a workflow state writes after a key: the plan's word for
# Linear's type, as a str, and a null for a type the plan has no word for.
# A started state whose name says review is in_review.
function state_type(state, __type, __name) {
  __type = text_of(member(state, "type"))
  __name = tolower(text_of(member(state, "name")))

  if (__type == "started" && index(__name, "review") > 0) {
    return "str=\"in_review\""
  }
  if (__type == "backlog") {
    return "str=\"backlog\""
  }
  if (__type == "unstarted") {
    return "str=\"todo\""
  }
  if (__type == "started") {
    return "str=\"in_progress\""
  }
  if (__type == "completed") {
    return "str=\"done\""
  }
  if (__type == "canceled") {
    return "str=\"cancelled\""
  }

  return "null"
}

# Prints a workflow state as a state of the plan, {name, type}, as members
# at a depth.
function print_state(state, depth) {
  print_node(member(state, "name"), depth, wrap("name"))
  print depth "." wrap("type") ":" state_type(state)
}

# Puts the children of a node in the order of the number each has under a
# name, in ORDERED[1..ORDERED_COUNT]. A child with no number orders first,
# and children with the same number keep their order.
function order_children(parent, name, __child, __place) {
  ORDERED_COUNT = 0

  for (__child = NODE_FIRST[parent]; __child != 0; __child = NODE_NEXT[__child]) {
    ORDERED_COUNT++
    __place = ORDERED_COUNT
    while (__place > 1 && number_orders_before(member(__child, name), member(ORDERED[__place - 1], name))) {
      ORDERED[__place] = ORDERED[__place - 1]
      __place--
    }
    ORDERED[__place] = __child
  }
}

# Whether the number of node a orders before the number of node b. No
# number orders before every number.
function number_orders_before(a, b) {
  if (!is_present(b)) {
    return 0
  }
  if (!is_present(a)) {
    return 1
  }

  return (NODE_VALUE[a] + 0) < (NODE_VALUE[b] + 0)
}

# Prints the states of a team record by position, each {name, type}, as a
# list under a key at a depth.
function print_states_of_team(team, depth, key, __i) {
  print_open(depth, key, "list")
  order_children(member(member(team, "states"), "nodes"), "position")

  for (__i = 1; __i <= ORDERED_COUNT; __i++) {
    print_open(depth + 1, __i - 1, "map")
    print_state(ORDERED[__i], depth + 2)
  }
}

# The node that names the lane of an issue: the name of its project's first
# initiative, else of its project, else no node.
function lane_of(issue, __project, __initiative) {
  __project = member(issue, "project")
  __initiative = member(child(member(member(__project, "initiatives"), "nodes"), 0), "name")

  if (is_present(__initiative)) {
    return __initiative
  }
  if (is_present(member(__project, "name"))) {
    return member(__project, "name")
  }

  return 0
}

# Prints a node at a depth under a key, and a null where it is missing.
function print_or_null(node, depth, name) {
  if (is_present(node)) {
    print_node(node, depth, wrap(name))
  } else {
    print depth "." wrap(name) ":null"
  }
}

# Prints an issue record as a ticket of the plan, as members at a depth.
# stub is the word true for a ticket outside the scope and false otherwise.
function print_ticket(issue, depth, stub) {
  print_node(member(issue, "id"), depth, wrap("id"))
  print_node(member(issue, "identifier"), depth, wrap("key"))
  print_node(member(issue, "title"), depth, wrap("title"))
  print_open(depth, wrap("state"), "map")
  print_state(member(issue, "state"), depth + 1)
  print_node(member(issue, "estimate"), depth, wrap("estimate"))
  print_node(member(issue, "priority"), depth, wrap("priority"))
  print_or_null(member(member(issue, "assignee"), "name"), depth, "assignee")
  print_or_null(member(member(issue, "projectMilestone"), "id"), depth, "milestone")
  print_or_null(lane_of(issue), depth, "lane")
  print_node(member(issue, "url"), depth, wrap("url"))
  if (is_present(member(issue, "description"))) {
    print_node(member(issue, "description"), depth, wrap("description"))
  } else {
    print_str(depth, "description", "")
  }
  print depth "." wrap("stub") ":bool=" stub
}
