# Prints the closed pull requests that merged at or after a time, shaped
# for the release chain: a list of {iid, merged_at, labels: [name...]}.
#
# Input: a list of pull requests as the pulls endpoint lists them.
# Argument "since": the time, ISO 8601 in UTC, which orders as text. An
#                   empty "since" means from genesis.

function main(line) {
  tree_line(line)
}

# Whether a pull request merged, at or after the time asked for.
function merged_since(pull, since, __merged_at) {
  __merged_at = member(pull, "merged_at")
  if (!is_present(__merged_at)) {
    return 0
  }

  return since == "" || (text_of(__merged_at) "") >= (since "")
}

# Prints one pull request as the record at an index.
function print_record(pull, index_in_list, __label, __names) {
  print_open(0, index_in_list, "map")
  print_node(member(pull, "number"), 1, wrap("iid"))
  print_node(member(pull, "merged_at"), 1, wrap("merged_at"))
  print_open(1, wrap("labels"), "list")

  __names = 0
  for (__label = NODE_FIRST[member(pull, "labels")]; __label != 0; __label = NODE_NEXT[__label]) {
    print_node(member(__label, "name"), 2, __names)
    __names++
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
  for (pull = NODE_FIRST[ROOT]; pull != 0; pull = NODE_NEXT[pull]) {
    if (merged_since(pull, arg("since"))) {
      print_record(pull, records)
      records++
    }
  }

  if (records == 0) {
    print "0.:list"
  }
}

{ main($0) }
