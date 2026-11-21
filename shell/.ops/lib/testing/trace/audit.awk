# Prints the reads that the static selection does not answer for: every
# file that a test read in the trace map where a change to the file would
# not select that test, with the area the file is under and the tests that
# read it, in the byte order of the files. Loaded after testing.awk.
#
# A change to a file selects for the file's areas: the area whose source
# covers it, and when there is none, every area that lists it as a test. A
# read is answered for when one of those areas lists the test under its
# suite, runs the full suite, or is code with no test, which widens the
# run. It is also answered for when no area covers the file, because
# dispatch treats a change there as mapping drift.
#
# Input: the trace map (schema/testing-trace.schema.json), and ahead of
#        it, with --with, the attached areas: every area's tests as
#        selection fills them, the tests of its importers among them.
#
#   [{"file": ".envrc", "area": "repo.envrc", "tests": ["test/a.bats"]}]

function main(line) {
  tree_line(line)
}

# The names of the areas that a change to a file selects for, with a
# newline after each, looked up once for each file.
function areas_of(file, __area, __names) {
  if (file in AREAS_OF) {
    return AREAS_OF[file]
  }

  __names = ""
  if (source_area(AREAS, file)) {
    __names = SOURCE_AREA "\n"
  } else {
    for (__area = NODE_FIRST[AREAS]; __area != 0; __area = NODE_NEXT[__area]) {
      __names = __names (in_tests(__area, file) ? name_of(__area) "\n" : "")
    }
  }

  AREAS_OF[file] = __names
  return __names
}

# Whether the selection of an area is every test: the area runs the full
# suite, or it is code that no test speaks for. Looked up once for each
# area.
function widens(area) {
  if (!(area in WIDENS)) {
    WIDENS[area] = is_truthy(member(area, "full_suite")) \
      || (!is_truthy(member(area, "inert")) && test_count(area) == 0)
  }

  return WIDENS[area]
}

# How many tests an area lists, over every suite.
function test_count(area, __suite, __count) {
  __count = 0
  for (__suite = NODE_FIRST[member(area, "tests")]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    __count += NODE_COUNT[__suite]
  }

  return __count
}

# Whether an area lists a test under a suite.
function lists_test(area, suite, test, __test) {
  for (__test = NODE_FIRST[member(member(area, "tests"), suite)]; __test != 0; __test = NODE_NEXT[__test]) {
    if (text_of(__test) == test) {
      return 1
    }
  }

  return 0
}

# Whether a change to a file selects a test of a suite.
function selects(file, suite, test, __names, __count, __i, __area) {
  __count = split(areas_of(file), __names, "\n") - 1
  if (__count < 1) {
    return 1
  }

  for (__i = 1; __i <= __count; __i++) {
    __area = member(AREAS, __names[__i])
    if (widens(__area) || lists_test(__area, suite, test)) {
      return 1
    }
  }

  return 0
}

# Notes a test that read a file without a change to the file selecting it.
function note_gap(file, test) {
  if (!(file in GAP_TESTS)) {
    GAP_FILE[++GAP_FILES] = file
  }
  GAP_TEST[file, ++GAP_TESTS[file]] = test
}

# Notes every read of every test in the map that the selection does not
# answer for.
function read_gaps(__suite, __test, __read) {
  for (__suite = NODE_FIRST[member(ROOT, "suites")]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    for (__test = NODE_FIRST[member(__suite, "tests")]; __test != 0; __test = NODE_NEXT[__test]) {
      for (__read = NODE_FIRST[member(__test, "reads")]; __read != 0; __read = NODE_NEXT[__read]) {
        if (!selects(text_of(__read), name_of(__suite), name_of(__test))) {
          note_gap(text_of(__read), name_of(__test))
        }
      }
    }
  }
}

# Prints one file's finding as element n of the list: the file, the first
# of its areas, and the tests that read it, in byte order with each once.
function print_gap(file, n, __tests, __count, __i) {
  __count = GAP_TESTS[file]
  for (__i = 1; __i <= __count; __i++) {
    __tests[__i] = GAP_TEST[file, __i]
  }

  print_open(0, n, "map")
  print_str(1, "file", file)
  print_str(1, "area", substr(AREAS_OF[file], 1, index(AREAS_OF[file], "\n") - 1))
  print_open(1, wrap("tests"), "list")
  print_texts(__tests, unique_texts(__tests, __count), 1)
}

BEGIN {
  AREAS = tree_ahead()
  ROOT = tree_open()
  GAP_FILES = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  read_gaps()
  sort_texts(GAP_FILE, GAP_FILES)
  for (i = 1; i <= GAP_FILES; i++) {
    print_gap(GAP_FILE[i], i - 1)
  }
  if (GAP_FILES == 0) {
    print "0.:list"
  }
}

{ main($0) }
