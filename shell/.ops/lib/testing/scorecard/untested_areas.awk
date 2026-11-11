# Prints the names of the areas that are code no test speaks for, in byte
# order: an area with no test that is not declared inert, does not run the
# full suite, and has a source path. A full-suite area runs every test
# whatever it lists, and an area with no path is a grouping that no change
# can land in. Loaded after testing.awk.
#
# Input: the area rows, a list (from area_rows.awk).

function main(line) {
  tree_line(line)
}

# Whether a row's area is code that no test speaks for.
function is_untested(row) {
  return text_or(member(row, "total"), 0) + 0 == 0 \
    && !is_truthy(member(row, "inert")) \
    && !is_truthy(member(row, "full_suite")) \
    && NODE_COUNT[member(row, "paths")] > 0
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  count = 0
  for (row = NODE_FIRST[ROOT]; row != 0; row = NODE_NEXT[row]) {
    if (is_untested(row)) {
      names[++count] = text_of(member(row, "name"))
    }
  }

  if (count == 0) {
    print "0.:list"
  }
  sort_texts(names, count)
  print_texts(names, count, -1)
}

{ main($0) }
