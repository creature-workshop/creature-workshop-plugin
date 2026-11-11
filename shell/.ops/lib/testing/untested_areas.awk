# Prints the names of the areas that have no test and are not inert, in
# byte order. An area has no test when it has no tests block, or one in
# which every suite is empty. Loaded after testing.awk.
#
# Input: the areas.

function main(line) {
  tree_line(line)
}

# Whether every suite of an area is empty.
function untested(area, __suite) {
  for (__suite = NODE_FIRST[member(area, "tests")]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    if (NODE_COUNT[__suite] > 0 || (NODE_TYPE[__suite] == "str" && text_of(__suite) != "")) {
      return 0
    }
  }

  return 1
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  count = 0
  for (area = NODE_FIRST[ROOT]; area != 0; area = NODE_NEXT[area]) {
    inert = member(area, "inert")
    if ((!is_present(inert) || text_of(inert) == "false") && untested(area)) {
      names[++count] = name_of(area)
    }
  }

  sort_texts(names, count)
  if (count == 0) {
    print "0.:list"
  }
  print_texts(names, count, -1)
}

{ main($0) }
