# Prints Linear issue records as tickets of the plan, a list. Loaded after
# tracker_issue.awk.

function main(line) {
  tree_line(line)
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  tickets = 0
  for (issue = NODE_FIRST[ROOT]; issue != 0; issue = NODE_NEXT[issue]) {
    print_open(0, tickets, "map")
    print_ticket(issue, 1, "false")
    tickets++
  }

  if (tickets == 0) {
    print "0.:list"
  }
}

{ main($0) }
