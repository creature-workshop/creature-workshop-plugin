# Prints the files that discovery may list, that the paths cover, and whose
# base name matches one of the globs and none of the excludes, in byte
# order and each once. Loaded after testing.awk.
#
# Input: the files, and ahead of them, with --with and in this order: the
#        paths, the globs and the excludes.

function main(line) {
  tree_line(line)
}

BEGIN {
  PATHS = tree_ahead()
  GLOBS = tree_ahead()
  EXCLUDES = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  count = 0
  for (file = NODE_FIRST[ROOT]; file != 0; file = NODE_NEXT[file]) {
    path = text_of(file)
    if (discoverable(path) && covered_by(PATHS, path) && matching(path, GLOBS, EXCLUDES)) {
      found[++count] = path
    }
  }

  count = unique_texts(found, count)
  if (count == 0) {
    print "0.:list"
  }
  print_texts(found, count, -1)
}

{ main($0) }
