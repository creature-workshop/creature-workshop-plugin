# Prints two selections joined: for every suite either has, the files of
# both, in byte order and each once. The suites are in byte order too.
# Loaded after testing.awk.
#
# Input: a selection, a map of suite to files, and ahead of it, with
#        --with, the other selection.

function main(line) {
  tree_line(line)
}

# Adds the names of the suites of a selection to SUITES.
function note_suites(selection, __suite) {
  for (__suite = NODE_FIRST[selection]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    SUITES[++SUITE_COUNT] = name_of(__suite)
  }
}

# Prints the files both selections have for one suite.
function print_suite(name, __file, __files, __count) {
  __count = 0
  for (__file = NODE_FIRST[member(ROOT, name)]; __file != 0; __file = NODE_NEXT[__file]) {
    __files[++__count] = text_of(__file)
  }
  for (__file = NODE_FIRST[member(OTHER, name)]; __file != 0; __file = NODE_NEXT[__file]) {
    __files[++__count] = text_of(__file)
  }

  print_open(0, wrap(name), "list")
  print_texts(__files, unique_texts(__files, __count), 0)
}

BEGIN {
  OTHER = tree_ahead()
  ROOT = tree_open()
  SUITE_COUNT = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  note_suites(ROOT)
  note_suites(OTHER)
  SUITE_COUNT = unique_texts(SUITES, SUITE_COUNT)
  for (i = 1; i <= SUITE_COUNT; i++) {
    print_suite(SUITES[i])
  }

  if (SUITE_COUNT == 0) {
    print "0.:map"
  }
}

{ main($0) }
