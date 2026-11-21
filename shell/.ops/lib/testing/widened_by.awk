# Prints the picked areas that run their full suite, each with the changed
# files it owns, as a list of {area, files} in the order of the areas'
# names. A file is owned by the area whose source covers it most
# specifically. The files are in byte order. Loaded after testing.awk.
#
# Input: the areas, and ahead of them, with --with and in this order: the
#        picked areas and the changed files.

function main(line) {
  tree_line(line)
}

BEGIN {
  PICKED = tree_ahead()
  CHANGED = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  for (file = NODE_FIRST[CHANGED]; file != 0; file = NODE_NEXT[file]) {
    if (source_area(ROOT, text_of(file))) {
      OWNED[SOURCE_AREA] = OWNED[SOURCE_AREA] text_of(file) "\n"
    }
  }

  count = 0
  for (area = NODE_FIRST[PICKED]; area != 0; area = NODE_NEXT[area]) {
    if (written(member(area, "full_suite")) == "bool=true") {
      names[++count] = name_of(area)
    }
  }
  sort_texts(names, count)

  for (i = 1; i <= count; i++) {
    owned = split(OWNED[names[i]], files, "\n") - 1
    if (owned < 0) {
      owned = 0
    }
    sort_texts(files, owned)
    print_open(0, i - 1, "map")
    print_str(1, "area", names[i])
    print_open(1, wrap("files"), "list")
    print_texts(files, owned, 1)
  }

  if (count == 0) {
    print "0.:list"
  }
}

{ main($0) }
