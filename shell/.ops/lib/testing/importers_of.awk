# Prints the areas whose tests a change to the named areas must run: the
# named areas and every area that imports one of them, directly or through
# another, in byte order and each once. Loaded after testing.awk.
#
# Input: the areas, and ahead of them, with --with and in this order: the
#        file edges of the import graph, each {from, to}, and the names.

function main(line) {
  tree_line(line)
}

BEGIN {
  EDGES = tree_ahead()
  NAMES = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  read_area_edges(ROOT, EDGES)
  count = 0
  for (name = NODE_FIRST[NAMES]; name != 0; name = NODE_NEXT[name]) {
    seen[++count] = text_of(name)
  }

  count = reach(seen, count, reached)
  if (count == 0) {
    print "0.:list"
  }
  print_texts(reached, count, -1)
}

{ main($0) }
