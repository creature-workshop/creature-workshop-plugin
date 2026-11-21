# Prints the merge requests that a reviewer is waiting on the author of,
# each as {iid, url, branch, draft, reviewers: [username...]}.
#
# GitLab records a review state for each reviewer, on that reviewer's
# interaction with the merge request, so a merge request with two reviewers
# can be waiting on one and settled with the other. Only the reviewers
# whose state is REQUESTED_CHANGES are listed. A merge request with none of
# them is left out, because a record with no reviewer would answer the
# question "who is waiting" wrongly.

function main(line) {
  tree_line(line)
}

# Notes the reviewers of a merge request who requested changes, in
# WAITER[1..WAITING].
function note_waiting(request, __reviewer) {
  WAITING = 0

  for (__reviewer = NODE_FIRST[member(member(request, "reviewers"), "nodes")]; __reviewer != 0; __reviewer = NODE_NEXT[__reviewer]) {
    if (text_of(member(member(__reviewer, "mergeRequestInteraction"), "reviewState")) == "REQUESTED_CHANGES") {
      WAITING++
      WAITER[WAITING] = member(__reviewer, "username")
    }
  }
}

# Prints one merge request as the record at an index, with the reviewers
# noted.
function print_record(request, index_in_list, __i) {
  print_open(0, index_in_list, "map")
  print_as(member(request, "iid"), 1, "iid")
  print_as(member(request, "webUrl"), 1, "url")
  print_as(member(request, "sourceBranch"), 1, "branch")
  print_as(member(request, "draft"), 1, "draft")
  print_open(1, wrap("reviewers"), "list")

  for (__i = 1; __i <= WAITING; __i++) {
    print_node(WAITER[__i], 2, __i - 1)
  }
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  records = 0
  for (request = NODE_FIRST[ROOT]; request != 0; request = NODE_NEXT[request]) {
    note_waiting(request)
    if (WAITING > 0) {
      print_record(request, records)
      records++
    }
  }

  if (records == 0) {
    print "0.:list"
  }
}

{ main($0) }
