# Prints the test files discovery derives for every area and every suite,
# as a map of area to a map of suite to files, each list in byte order with
# each file once and empty where nothing matched. Loaded after testing.awk.
#
# Input: the candidate files, paths under the project, and ahead of them,
#        with --with and in this order: the areas, the resolved suites,
#        {<suite>: {root, globs, excludes, discovery}}, and what the
#        runners' own discovery derived, {<area>: {<suite>: [files]}}.
#
# Two strategies are resolved here, for a suite whose discovery names
# them. "sibling" keeps the area's own files that match the suite's
# patterns. "filename" keeps the tests under the suite's root whose stem is
# the stem of one of the area's files. The files of each area and the
# tests of each suite are indexed once over the whole list.

function main(line) {
  tree_line(line)
}

# Notes which areas declare each path, with a newline after each area's
# name.
function note_areas_by_path(__area, __path) {
  for (__area = NODE_FIRST[AREAS]; __area != 0; __area = NODE_NEXT[__area]) {
    for (__path = NODE_FIRST[member(__area, "paths")]; __path != 0; __path = NODE_NEXT[__path]) {
      AREAS_AT[text_of(__path)] = AREAS_AT[text_of(__path)] name_of(__area) "\n"
    }
  }
}

# Reads the files that discovery may list into FILE[1..FILES], and files
# each under every area that declares it or a directory above it.
function read_files(__file, __path) {
  FILES = 0

  for (__file = NODE_FIRST[ROOT]; __file != 0; __file = NODE_NEXT[__file]) {
    __path = text_of(__file)
    if (discoverable(__path)) {
      FILE[++FILES] = __path
      file_under_areas(__path)
    }
  }
}

# Adds a file to the files of every area that declares it or a directory
# above it, and its stem to the stems of each.
function file_under_areas(file, __above, __count, __i, __names, __areas, __j) {
  __count = ancestors(file, __above)

  for (__i = 1; __i <= __count; __i++) {
    __areas = split(AREAS_AT[__above[__i]], __names, "\n")
    for (__j = 1; __j < __areas; __j++) {
      FILES_OF[__names[__j]] = FILES_OF[__names[__j]] file "\n"
      STEMS_OF[__names[__j]] = STEMS_OF[__names[__j]] stem(file) "\n"
    }
  }
}

# Reads every suite once: whether its discovery names each strategy, and
# the tests under its root by the stem the filename strategy compares.
# Suite n is SUITE[n], and RUNS_SIBLING[n] and RUNS_FILENAME[n] say which
# strategies it runs.
function read_suites(__suite, __strategy) {
  SUITE_COUNT = 0

  for (__suite = NODE_FIRST[SUITES]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    SUITE_COUNT++
    SUITE[SUITE_COUNT] = __suite
    RUNS_SIBLING[SUITE_COUNT] = 0
    RUNS_FILENAME[SUITE_COUNT] = 0

    for (__strategy = NODE_FIRST[member(__suite, "discovery")]; __strategy != 0; __strategy = NODE_NEXT[__strategy]) {
      if (text_of(__strategy) == "sibling") {
        RUNS_SIBLING[SUITE_COUNT] = 1
      }
      if (text_of(__strategy) == "filename") {
        RUNS_FILENAME[SUITE_COUNT] = 1
      }
    }
    index_root_tests(SUITE_COUNT, __suite)
  }
}

# Notes the tests under a suite's root by stem, in TESTS_AT[n, stem], with
# a newline after each. A suite with no root has none.
function index_root_tests(n, suite, __root, __globs, __excludes, __i, __stem) {
  __root = text_or(member(suite, "root"), "")
  if (__root == "") {
    return
  }

  __globs = member(suite, "globs")
  __excludes = member(suite, "excludes")
  for (__i = 1; __i <= FILES; __i++) {
    if (covers(__root, FILE[__i]) && matching(FILE[__i], __globs, __excludes)) {
      __stem = candidate_stem(FILE[__i], __globs)
      TESTS_AT[n, __stem] = TESTS_AT[n, __stem] FILE[__i] "\n"
    }
  }
}

# The stem of a test file: its base name without the first of the suite's
# glob suffixes it ends with, where a glob's suffix is the glob without its
# leading "*". string.api.bats with *.bats is string.api.
function candidate_stem(file, globs, __name, __glob, __suffix) {
  __name = base_name(file)

  for (__glob = NODE_FIRST[globs]; __glob != 0; __glob = NODE_NEXT[__glob]) {
    __suffix = text_of(__glob)
    sub(/^\*/, "", __suffix)
    if (length(__name) >= length(__suffix) && substr(__name, length(__name) - length(__suffix) + 1) == __suffix) {
      return substr(__name, 1, length(__name) - length(__suffix))
    }
  }

  return __name
}

# Prints the files one area derives for suite n, under the suite's key at
# depth 1.
function print_derived(area, n, __files, __count, __own, __owned, __i, __stems, __stem_count, __tests, __test_count, __j, __extra, __globs, __excludes) {
  __count = 0

  if (RUNS_SIBLING[n]) {
    __globs = member(SUITE[n], "globs")
    __excludes = member(SUITE[n], "excludes")
    __owned = split(FILES_OF[area], __own, "\n") - 1
    for (__i = 1; __i <= __owned; __i++) {
      if (matching(__own[__i], __globs, __excludes)) {
        __files[++__count] = __own[__i]
      }
    }
  }
  if (RUNS_FILENAME[n]) {
    __stem_count = split(STEMS_OF[area], __stems, "\n") - 1
    for (__i = 1; __i <= __stem_count; __i++) {
      __test_count = split(TESTS_AT[n, __stems[__i]], __tests, "\n") - 1
      for (__j = 1; __j <= __test_count; __j++) {
        __files[++__count] = __tests[__j]
      }
    }
  }
  for (__extra = NODE_FIRST[child(member(RUNNER, area), NODE_KEY[SUITE[n]])]; __extra != 0; __extra = NODE_NEXT[__extra]) {
    __files[++__count] = text_of(__extra)
  }

  print_open(1, NODE_KEY[SUITE[n]], "list")
  print_texts(__files, unique_texts(__files, __count), 1)
}

BEGIN {
  AREAS = tree_ahead()
  SUITES = tree_ahead()
  RUNNER = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  note_areas_by_path()
  read_files()
  read_suites()

  areas = 0
  for (area = NODE_FIRST[AREAS]; area != 0; area = NODE_NEXT[area]) {
    print_open(0, NODE_KEY[area], "map")
    for (n = 1; n <= SUITE_COUNT; n++) {
      print_derived(name_of(area), n)
    }
    areas++
  }

  if (areas == 0) {
    print "0.:map"
  }
}

{ main($0) }
