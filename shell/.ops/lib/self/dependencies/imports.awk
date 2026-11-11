# Prints the run-time trees of a lock's dependencies section: the map
# under imports. For a lock written before that map existed, prints the
# run-time entries of its git map, each without its scope. Prints the empty
# map when the section records neither.

function main(line) {
  tree_line(line)
}

# Prints the run-time entries of the git map, each without its scope.
function print_run_time(git, __tree, __field, __trees) {
  __trees = 0

  for (__tree = NODE_FIRST[git]; __tree != 0; __tree = NODE_NEXT[__tree]) {
    if (text_of(member(__tree, "scope")) != "run-time") {
      continue
    }

    print_open(0, NODE_KEY[__tree], "map")
    for (__field = NODE_FIRST[__tree]; __field != 0; __field = NODE_NEXT[__field]) {
      if (NODE_KEY[__field] != wrap("scope")) {
        print_node(__field, 1, NODE_KEY[__field])
      }
    }
    __trees++
  }

  if (__trees == 0) {
    print "0.:map"
  }
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  if (member(ROOT, "imports") != 0) {
    print_document(member(ROOT, "imports"))
  } else {
    print_run_time(member(ROOT, "git"))
  }
}

{ main($0) }
