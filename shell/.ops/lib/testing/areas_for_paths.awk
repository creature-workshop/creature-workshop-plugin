# Prints the areas that changed files belong to, as a list of names in
# byte order, each once. A file belongs to the area whose source covers it
# most specifically, and when no source covers it, to every area that lists
# it among its tests. Loaded after testing.awk.
#
# Input: the areas, and ahead of them, with --with, the changed files.

function main(line) {
  tree_line(line)
}

# Adds the areas of one file to NAMES.
function add_areas_of(file, __area) {
  if (source_area(ROOT, file)) {
    NAMES[++COUNT] = SOURCE_AREA
    return
  }

  for (__area = NODE_FIRST[ROOT]; __area != 0; __area = NODE_NEXT[__area]) {
    if (in_tests(__area, file)) {
      NAMES[++COUNT] = name_of(__area)
    }
  }
}

BEGIN {
  CHANGED = tree_ahead()
  ROOT = tree_open()
  COUNT = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  for (file = NODE_FIRST[CHANGED]; file != 0; file = NODE_NEXT[file]) {
    add_areas_of(text_of(file))
  }

  COUNT = unique_texts(NAMES, COUNT)
  if (COUNT == 0) {
    print "0.:list"
  }
  print_texts(NAMES, COUNT, -1)
}

{ main($0) }
