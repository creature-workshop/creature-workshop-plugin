# Prints the test files of the named areas, suite by suite. A suite that
# two of the areas have holds the files of both, in byte order and each
# once. A suite that one area has is printed as that area has it. A suite
# with no file is left out. Loaded after testing.awk.
#
# Input: the areas with each area's tests filled in, and ahead of them,
#        with --with, the names.

function main(line) {
  tree_line(line)
}

# Lays the tests of one area over the tests so far.
function lay_tests(tests, __suite, __name) {
  for (__suite = NODE_FIRST[tests]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    __name = NODE_KEY[__suite]
    if (!(__name in LATEST)) {
      SUITES++
      SUITE[SUITES] = __name
      JOINED[__name] = 0
    } else if (NODE_TYPE[LATEST[__name]] == "list" && NODE_TYPE[__suite] == "list") {
      JOINED[__name] = 1
    } else {
      JOINED[__name] = 0
      FILES_OF[__name] = ""
    }

    LATEST[__name] = __suite
    FILES_OF[__name] = FILES_OF[__name] joined_files(__suite)
  }
}

# The files under a node, with a newline after each.
function joined_files(suite, __file, __joined) {
  __joined = ""
  for (__file = NODE_FIRST[suite]; __file != 0; __file = NODE_NEXT[__file]) {
    __joined = __joined text_of(__file) "\n"
  }

  return __joined
}

# Prints one suite, and returns 1, or prints nothing and returns 0 when
# the suite holds nothing.
function print_suite(name, __files, __count) {
  if (!JOINED[name]) {
    if (NODE_COUNT[LATEST[name]] == 0 && text_or(LATEST[name], "") == "") {
      return 0
    }
    print_node(LATEST[name], 0, name)
    return 1
  }

  __count = unique_texts(__files, split(FILES_OF[name], __files, "\n") - 1)
  if (__count == 0) {
    return 0
  }
  print_open(0, name, "list")
  print_texts(__files, __count, 0)
  return 1
}

BEGIN {
  NAMES = tree_ahead()
  ROOT = tree_open()
  SUITES = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  for (name = NODE_FIRST[NAMES]; name != 0; name = NODE_NEXT[name]) {
    tests = member(member(ROOT, text_of(name)), "tests")
    if (is_present(tests) && text_of(tests) != "false") {
      lay_tests(tests)
    }
  }

  printed = 0
  for (i = 1; i <= SUITES; i++) {
    printed += print_suite(SUITE[i])
  }

  if (printed == 0) {
    print "0.:map"
  }
}

{ main($0) }
