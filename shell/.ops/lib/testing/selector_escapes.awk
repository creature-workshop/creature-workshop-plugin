# Prints the failing tests each selector's own answer would have skipped,
# as a map of selector id to keys in byte order, each once. A selector
# speaks in files, so only the suite rows whose escape_key is file-path are
# judged. Loaded after testing.awk.
#
# Input: the run's metrics record, and ahead of it, with --with, the failed
#        keys of each suite, a map of suite to keys.
#
#   {"areas": [], "trace": ["test/b.bats"]}

function main(line) {
  tree_line(line)
}

# Notes the suites whose rows are keyed by file, in SUITE[1..SUITES].
function note_file_keyed_suites(__row) {
  SUITES = 0

  for (__row = NODE_FIRST[member(ROOT, "suites")]; __row != 0; __row = NODE_NEXT[__row]) {
    if (text_or(member(__row, "escape_key"), "file-path") == "file-path") {
      SUITE[++SUITES] = text_of(member(__row, "suite"))
    }
  }
}

# Prints the escapes of one selector under its id: the failures of every
# file-keyed suite that its tests for that suite do not include.
function print_selector(selector, __i, __key, __ran, __escapes, __count, __name) {
  __count = 0

  for (__i = 1; __i <= SUITES; __i++) {
    for (__name in __ran) {
      delete __ran[__name]
    }
    for (__key = NODE_FIRST[member(member(selector, "tests"), SUITE[__i])]; __key != 0; __key = NODE_NEXT[__key]) {
      __ran[text_of(__key)] = 1
    }
    for (__key = NODE_FIRST[member(FAILED, SUITE[__i])]; __key != 0; __key = NODE_NEXT[__key]) {
      if (!(text_of(__key) in __ran)) {
        __escapes[++__count] = text_of(__key)
      }
    }
  }

  print_open(0, wrap(text_of(member(selector, "id"))), "list")
  print_texts(__escapes, unique_texts(__escapes, __count), 0)
}

BEGIN {
  FAILED = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  note_file_keyed_suites()
  selectors = member(member(ROOT, "selection"), "selectors")
  for (selector = NODE_FIRST[selectors]; selector != 0; selector = NODE_NEXT[selector]) {
    LAST_WITH_ID[text_of(member(selector, "id"))] = selector
  }

  printed = 0
  for (selector = NODE_FIRST[selectors]; selector != 0; selector = NODE_NEXT[selector]) {
    id = text_of(member(selector, "id"))
    if (!(id in PRINTED)) {
      print_selector(LAST_WITH_ID[id])
      PRINTED[id] = 1
      printed++
    }
  }

  if (printed == 0) {
    print "0.:map"
  }
}

{ main($0) }
