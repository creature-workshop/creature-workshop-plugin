# Prints the commits that the entries of a trace map were traced at, in
# byte order with each once. An entry that names no commit adds none.
# Loaded after testing.awk.
#
# Input: the trace map (schema/testing-trace.schema.json).

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

  count = 0
  for (suite = NODE_FIRST[member(ROOT, "suites")]; suite != 0; suite = NODE_NEXT[suite]) {
    for (test = NODE_FIRST[member(suite, "tests")]; test != 0; test = NODE_NEXT[test]) {
      if (NODE_TYPE[member(test, "commit")] == "str") {
        commits[++count] = text_of(member(test, "commit"))
      }
    }
  }

  count = unique_texts(commits, count)
  if (count == 0) {
    print "0.:list"
  }
  print_texts(commits, count, -1)
}

{ main($0) }
