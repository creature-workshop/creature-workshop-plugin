# Prints what the trace map selects for a diff against the commit it was
# recorded at, which of the review's changed files the map can speak for,
# and which tests it speaks for. Loaded after testing.awk.
#
# The map selects a test when the test read a path that the diff changed
# or removed, or looked for a path that the diff added. It also selects
# every test file that the diff itself touches: a test the map has an
# entry for, or a new file that a suite's root and patterns recognise.
#
# The map claims a changed file when it has a fact about the file, a read
# or a probe, or when the file is a test file. A changed file it does not
# claim is left for the next selector. The tests it speaks for are the
# ones it has an entry for. A suite marked out_of_tree is left out
# throughout, because the reads recorded for it are never complete.
#
# Input: the trace map (schema/testing-trace.schema.json), and ahead of
#        it, with --with and in this order: the diff against the map's
#        commit, a list of "<status>\t<path>" lines; the review's changed
#        files; and the effective suites, whose root, glob and exclude say
#        what a new test file looks like.
#
#   {tests: {unit: ["test/a.bats"]}, claimed: ["lib/a.sh"], unclaimed: ["docs/x.md"],
#    known: {unit: ["test/a.bats", "test/b.bats"]}}

function main(line) {
  tree_line(line)
}

# Reads the diff: every path into DIFF_PATH[1..DIFF_PATHS], the added ones
# into IS_ADDED, and the changed or removed ones into IS_TOUCHED. A line
# that is not a status and a path is skipped.
function read_diff(__line, __fields) {
  DIFF_PATHS = 0

  for (__line = NODE_FIRST[DIFF]; __line != 0; __line = NODE_NEXT[__line]) {
    if (split(text_of(__line), __fields, "\t") != 2) {
      continue
    }

    DIFF_PATH[++DIFF_PATHS] = __fields[2]
    if (__fields[1] == "A") {
      IS_ADDED[__fields[2]] = 1
    } else {
      IS_TOUCHED[__fields[2]] = 1
    }
  }
}

# Whether the trace may speak for a suite: every suite but one that the
# effective suites mark out_of_tree.
function is_in_tree(name) {
  return text_of(member(member(SUITES, name), "reach")) != "out_of_tree"
}

# Reads the map's suites that the trace may speak for into
# TRACED[1..TRACEDS], notes every path the map has a fact about and every
# test it has an entry for, and selects the tests that meet the diff.
function read_map(__suite, __test) {
  TRACEDS = 0

  for (__suite = NODE_FIRST[member(ROOT, "suites")]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    if (!is_in_tree(name_of(__suite))) {
      continue
    }

    TRACED[++TRACEDS] = __suite
    for (__test = NODE_FIRST[member(__suite, "tests")]; __test != 0; __test = NODE_NEXT[__test]) {
      HAS_ENTRY[name_of(__test)] = 1
      if (note_facts(__test)) {
        select_test(name_of(__suite), name_of(__test))
      }
    }
  }
}

# Notes the paths a test read and looked for as paths the map has a fact
# about. Returns whether the test meets the diff: it read a path the diff
# changed or removed, or looked for one the diff added.
function note_facts(test, __path, __meets) {
  __meets = 0

  for (__path = NODE_FIRST[member(test, "reads")]; __path != 0; __path = NODE_NEXT[__path]) {
    HAS_FACT[text_of(__path)] = 1
    __meets = __meets || (text_of(__path) in IS_TOUCHED)
  }
  for (__path = NODE_FIRST[member(test, "probes")]; __path != 0; __path = NODE_NEXT[__path]) {
    HAS_FACT[text_of(__path)] = 1
    __meets = __meets || (text_of(__path) in IS_ADDED)
  }

  return __meets
}

# Selects a test for a suite. Suite n is SELECTED_SUITE[n], in the order
# the suites are first selected for, and its tests are
# SELECTED[n, 1..SELECTED_COUNT[n]].
function select_test(suite, test, __n) {
  if (!(suite in SELECTED_AT)) {
    SELECTED_AT[suite] = ++SELECTED_SUITES
    SELECTED_SUITE[SELECTED_SUITES] = suite
  }

  __n = SELECTED_AT[suite]
  SELECTED[__n, ++SELECTED_COUNT[__n]] = test
}

# Selects every test file the diff touches, for each suite it is a test
# file of.
function select_touched_tests(__i, __suites, __count, __j) {
  for (__i = 1; __i <= DIFF_PATHS; __i++) {
    __count = suites_of_test(DIFF_PATH[__i], __suites)
    for (__j = 1; __j <= __count; __j++) {
      select_test(__suites[__j], DIFF_PATH[__i])
    }
  }
}

# Fills suites with the names of the suites a path is a test file of, in
# byte order: the traced suites that have an entry for it, and the suites
# whose root and patterns recognise it. Returns how many there are.
function suites_of_test(path, suites, __i, __count, __suite) {
  __count = 0

  for (__i = 1; __i <= TRACEDS; __i++) {
    if (member(member(TRACED[__i], "tests"), path) != 0) {
      suites[++__count] = name_of(TRACED[__i])
    }
  }
  for (__suite = NODE_FIRST[SUITES]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    if (recognises(__suite, path)) {
      suites[++__count] = name_of(__suite)
    }
  }

  return unique_texts(suites, __count)
}

# Whether a suite's root and patterns recognise a path as one of its test
# files. A suite that is out_of_tree, or that has no root, recognises
# none.
function recognises(suite, path, __root) {
  __root = text_or(member(suite, "root"), "")
  if (__root == "" || !is_in_tree(name_of(suite)) || !covers(__root, path)) {
    return 0
  }

  return matches_patterns(base_name(path), member(suite, "glob")) \
    && !matches_patterns(base_name(path), member(suite, "exclude"))
}

# Whether a name matches a suite's patterns, which are a list of globs or
# one glob as a str.
function matches_patterns(name, patterns) {
  if (NODE_TYPE[patterns] == "str") {
    return glob_matches(name, text_of(patterns))
  }

  return NODE_TYPE[patterns] == "list" && matches_any(name, patterns)
}

# Whether the map can speak for a changed file: it has a fact about the
# file, or the file is a test file, one it has an entry for or a new one.
function is_claimed(file, __suites) {
  return (file in HAS_FACT) || (file in HAS_ENTRY) || suites_of_test(file, __suites) > 0
}

# Prints the selected tests of each suite, in byte order with each once.
function print_tests(__n, __i, __tests, __count) {
  print_open(0, wrap("tests"), "map")

  for (__n = 1; __n <= SELECTED_SUITES; __n++) {
    __count = SELECTED_COUNT[__n]
    for (__i = 1; __i <= __count; __i++) {
      __tests[__i] = SELECTED[__n, __i]
    }
    print_open(1, wrap(SELECTED_SUITE[__n]), "list")
    print_texts(__tests, unique_texts(__tests, __count), 1)
  }
}

# Prints the changed files under a name: the claimed ones when claimed is
# 1, and the others when it is 0.
function print_changed(name, claimed, __file, __files, __count) {
  __count = 0
  for (__file = NODE_FIRST[CHANGED]; __file != 0; __file = NODE_NEXT[__file]) {
    if (is_claimed(text_of(__file)) == claimed) {
      __files[++__count] = text_of(__file)
    }
  }

  print_open(0, wrap(name), "list")
  print_texts(__files, __count, 0)
}

# Prints the tests the map has an entry for, for each traced suite, in
# byte order.
function print_known(__i, __test, __tests, __count) {
  print_open(0, wrap("known"), "map")

  for (__i = 1; __i <= TRACEDS; __i++) {
    __count = 0
    for (__test = NODE_FIRST[member(TRACED[__i], "tests")]; __test != 0; __test = NODE_NEXT[__test]) {
      __tests[++__count] = name_of(__test)
    }
    print_open(1, NODE_KEY[TRACED[__i]], "list")
    print_texts(__tests, unique_texts(__tests, __count), 1)
  }
}

BEGIN {
  DIFF = tree_ahead()
  CHANGED = tree_ahead()
  SUITES = tree_ahead()
  ROOT = tree_open()
  SELECTED_SUITES = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  read_diff()
  read_map()
  select_touched_tests()

  print_tests()
  print_changed("claimed", 1)
  print_changed("unclaimed", 0)
  print_known()
}

{ main($0) }
