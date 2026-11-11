# Prints the tickets that a filter keeps: every one whose state name,
# state type, milestone and assignee are the filter's, for each of those
# the filter sets.
#
# Input: the tickets, and ahead of them, with --with, the filter,
#        {state, type, milestone, assignee}.

function main(line) {
  tree_line(line)
}

# Whether the filter leaves a field unset: missing, a null or empty.
function unset(field) {
  return !is_present(member(FILTER, field)) || written(member(FILTER, field)) == "str=\"\""
}

# Whether a value of a ticket is the value the filter has for a field.
function matches(value, field) {
  return written(value) == written(member(FILTER, field))
}

# Whether the filter keeps a ticket.
function keeps(ticket, __state) {
  __state = member(ticket, "state")

  return (unset("state") || matches(member(__state, "name"), "state")) \
    && (unset("type") || matches(member(__state, "type"), "type")) \
    && (unset("milestone") || matches(member(ticket, "milestone"), "milestone")) \
    && (unset("assignee") || matches(member(ticket, "assignee"), "assignee"))
}

BEGIN {
  FILTER = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  kept = 0
  for (ticket = NODE_FIRST[ROOT]; ticket != 0; ticket = NODE_NEXT[ticket]) {
    if (keeps(ticket)) {
      print_node(ticket, 0, kept)
      kept++
    }
  }

  if (kept == 0) {
    print "0.:list"
  }
}

{ main($0) }
