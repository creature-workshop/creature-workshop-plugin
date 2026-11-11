# Prints one Linear issue record as a ticket of the plan. Loaded after
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

  print_ticket(ROOT, 0, "false")
}

{ main($0) }
