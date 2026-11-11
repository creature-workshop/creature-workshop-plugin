# Prints the failing tests a selection would have skipped, as a list in
# byte order with each once: for every suite row of a run's metrics record,
# the failed keys the row's run left out. Loaded after testing.awk.
#
# Input: the run's metrics record, and ahead of it, with --with, the failed
#        keys of each suite, a map of suite to keys, read under that
#        suite's escape_key.
#
# A record that ran the full suite has none, since nothing was left out. A
# row that ran nothing left everything out, so every failure of its suite
# is one. A row with no list of what it ran, ran its whole suite.

function main(line) {
  tree_line(line)
}

# What one row ran, in the keys its escape_key joins on: the packages
# under "package", and the tests otherwise.
function selected_keys(row) {
  if (text_or(member(row, "escape_key"), "file-path") == "package") {
    return member(row, "packages")
  }

  return member(row, "tests")
}

# Whether a row ran nothing.
function ran_nothing(row, __selected) {
  __selected = member(row, "selected")

  return (NODE_TYPE[__selected] == "int" || NODE_TYPE[__selected] == "float") && NODE_VALUE[__selected] + 0 == 0
}

# Adds the escapes of one row to ESCAPES.
function add_row_escapes(row, __failures, __selected, __key, __ran) {
  __failures = member(FAILED, text_of(member(row, "suite")))
  __selected = selected_keys(row)
  if (!ran_nothing(row) && !is_present(__selected)) {
    return
  }

  if (!ran_nothing(row)) {
    for (__key = NODE_FIRST[__selected]; __key != 0; __key = NODE_NEXT[__key]) {
      __ran[text_of(__key)] = 1
    }
  }
  for (__key = NODE_FIRST[__failures]; __key != 0; __key = NODE_NEXT[__key]) {
    if (!(text_of(__key) in __ran)) {
      ESCAPES[++COUNT] = text_of(__key)
    }
  }
}

BEGIN {
  FAILED = tree_ahead()
  ROOT = tree_open()
  COUNT = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  if (text_of(member(member(ROOT, "selection"), "mode")) != "full_suite") {
    for (row = NODE_FIRST[member(ROOT, "suites")]; row != 0; row = NODE_NEXT[row]) {
      add_row_escapes(row)
    }
  }

  COUNT = unique_texts(ESCAPES, COUNT)
  if (COUNT == 0) {
    print "0.:list"
  }
  print_texts(ESCAPES, COUNT, -1)
}

{ main($0) }
