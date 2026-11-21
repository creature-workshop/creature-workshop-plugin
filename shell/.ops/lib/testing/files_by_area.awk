# Prints, for each area, the files its paths cover, in byte order and each
# once. Loaded after testing.awk.
#
# Input: the files, and ahead of them, with --with, a map of area to its
#        paths.

function main(line) {
  tree_line(line)
}

BEGIN {
  AREAS = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  areas = 0
  for (area = NODE_FIRST[AREAS]; area != 0; area = NODE_NEXT[area]) {
    count = 0
    for (file = NODE_FIRST[ROOT]; file != 0; file = NODE_NEXT[file]) {
      if (covered_by(area, text_of(file))) {
        covered[++count] = text_of(file)
      }
    }

    print_open(0, NODE_KEY[area], "list")
    print_texts(covered, unique_texts(covered, count), 0)
    areas++
  }

  if (areas == 0) {
    print "0.:map"
  }
}

{ main($0) }
