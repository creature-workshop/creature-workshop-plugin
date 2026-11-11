# Prints the tests that the run selects: for each suite, the tests of
# every active selection. A selection is active when its mode is not the
# shadow mode. A suite that one selection names keeps that selection's
# list as it is. A suite that several name gets their tests in byte order
# with each test once. A suite with no test is left out. Loaded after
# testing.awk.
#
# When the active ground-truth selections claim every changed file between
# them, the tests of a prior are left out where a ground truth knows them.
# A ground truth knows the tests it lists under known, and one that lists
# none knows every test, so every prior is then left out whole. A run with
# no changed file settles nothing.
#
# Input: the selections, a list of {id, confidence, mode, tests, claimed,
#        unclaimed, known}, and ahead of them, with --with, the changed
#        files.
# Args:  prior and ground_truth, the two confidence words, and shadow, the
#        mode word of a selector whose answer goes into nothing.

function main(line) {
  tree_line(line)
}

# Reads the active selections into ACTIVE[1..ACTIVES], and what the ground
# truths among them claim and know.
function read_active(__selection) {
  ACTIVES = 0
  KNOWS_EVERY_TEST = 0

  for (__selection = NODE_FIRST[ROOT]; __selection != 0; __selection = NODE_NEXT[__selection]) {
    if (text_of(member(__selection, "mode")) == arg("shadow")) {
      continue
    }

    ACTIVE[++ACTIVES] = __selection
    if (is_ground_truth(__selection)) {
      note_ground_truth(__selection)
    }
  }
}

# Whether a selection's confidence is that of a ground truth.
function is_ground_truth(selection) {
  return text_of(member(selection, "confidence")) == arg("ground_truth")
}

# Whether a selection's confidence is that of a prior.
function is_prior(selection) {
  return text_of(member(selection, "confidence")) == arg("prior")
}

# Notes the files a ground truth claims and the tests it knows.
function note_ground_truth(selection, __file, __known, __suite, __test) {
  for (__file = NODE_FIRST[member(selection, "claimed")]; __file != 0; __file = NODE_NEXT[__file]) {
    IS_CLAIMED[text_of(__file)] = 1
  }

  __known = member(selection, "known")
  if (__known == 0) {
    KNOWS_EVERY_TEST = 1
  }
  for (__suite = NODE_FIRST[__known]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    for (__test = NODE_FIRST[__suite]; __test != 0; __test = NODE_NEXT[__test]) {
      IS_KNOWN[name_of(__suite), text_of(__test)] = 1
    }
  }
}

# Whether the ground truths claim every changed file, of which there is at
# least one.
function is_settled(__file) {
  for (__file = NODE_FIRST[CHANGED]; __file != 0; __file = NODE_NEXT[__file]) {
    if (!(text_of(__file) in IS_CLAIMED)) {
      return 0
    }
  }

  return NODE_COUNT[CHANGED] > 0
}

# Adds the tests of every active selection to the tests of their suites.
# In a settled run a prior adds only the tests that no ground truth knows.
function collect_tests(__i, __settled, __without_known) {
  __settled = is_settled()

  for (__i = 1; __i <= ACTIVES; __i++) {
    __without_known = __settled && is_prior(ACTIVE[__i])
    if (__without_known && KNOWS_EVERY_TEST) {
      continue
    }
    collect_selection(ACTIVE[__i], __without_known)
  }
}

# Adds the tests of one selection to the tests of their suites, without
# the tests a ground truth knows when that is asked for. Suite n is
# SUITE[n], SUITE_LISTS[n] is how many selections named it, and its tests
# so far are SUITE_TEST[n, 1..SUITE_TESTS[n]].
function collect_selection(selection, without_known, __suite, __test, __n) {
  for (__suite = NODE_FIRST[member(selection, "tests")]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    __n = suite_number(name_of(__suite))
    SUITE_LISTS[__n]++

    for (__test = NODE_FIRST[__suite]; __test != 0; __test = NODE_NEXT[__test]) {
      if (!without_known || !((name_of(__suite), text_of(__test)) in IS_KNOWN)) {
        SUITE_TEST[__n, ++SUITE_TESTS[__n]] = text_of(__test)
      }
    }
  }
}

# The number of a suite, in the order the selections first name them.
function suite_number(name) {
  if (!(name in SUITE_AT)) {
    SUITE_AT[name] = ++SUITES
    SUITE[SUITES] = name
  }

  return SUITE_AT[name]
}

# Prints the tests of suite n under its name, and nothing for a suite with
# no test.
function print_suite(n, __tests, __count, __i) {
  __count = SUITE_TESTS[n] + 0
  for (__i = 1; __i <= __count; __i++) {
    __tests[__i] = SUITE_TEST[n, __i]
  }
  if (SUITE_LISTS[n] > 1) {
    __count = unique_texts(__tests, __count)
  }
  if (__count == 0) {
    return 0
  }

  print_open(0, wrap(SUITE[n]), "list")
  print_texts(__tests, __count, 0)
  return 1
}

BEGIN {
  CHANGED = tree_ahead()
  ROOT = tree_open()
  SUITES = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  read_active()
  collect_tests()

  printed = 0
  for (n = 1; n <= SUITES; n++) {
    printed += print_suite(n)
  }
  if (printed == 0) {
    print "0.:map"
  }
}

{ main($0) }
