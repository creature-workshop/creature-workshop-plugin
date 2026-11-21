# Prints the merge requests that merged at or after a time, each as
# {iid, merged_at, labels: [title...]}.
#
# Input: the merge request nodes GitLab's GraphQL API lists.
# Argument "since": the time, ISO 8601 in UTC, which orders as text. An
#                   empty "since" keeps every merged merge request.
#
# GitLab's updatedAfter filters on the time of the last update, so the
# server also lists merge requests that were touched after "since" but
# merged before it. Those are left out here.

function main(line) {
  tree_line(line)
}

# Whether a merge request merged at or after the time asked for.
function merged_since(request, since, __merged_at) {
  __merged_at = member(request, "mergedAt")

  return is_present(__merged_at) && (text_of(__merged_at) "") >= (since "")
}

# Prints one merge request as the record at an index.
function print_record(request, index_in_list, __label, __titles) {
  print_open(0, index_in_list, "map")
  print_as(member(request, "iid"), 1, "iid")
  print_as(member(request, "mergedAt"), 1, "merged_at")
  print_open(1, wrap("labels"), "list")

  __titles = 0
  for (__label = NODE_FIRST[member(member(request, "labels"), "nodes")]; __label != 0; __label = NODE_NEXT[__label]) {
    print_node(member(__label, "title"), 2, __titles)
    __titles++
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
    if (merged_since(request, arg("since"))) {
      print_record(request, records)
      records++
    }
  }

  if (records == 0) {
    print "0.:list"
  }
}

{ main($0) }
