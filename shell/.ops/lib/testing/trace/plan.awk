# Prints the plan that a traced run starts from: the entries of the prior
# map that still hold, carried forward, and the files left to trace, in
# the byte order of the suites' names and of each suite's files. Loaded
# after testing.awk.
#
# An entry holds when its suite is still traced by the same runner, its
# file is still one of the suite's, it names the commit it was traced at,
# and none of the files it names, the test file among them, differs
# between that commit and this run's. A file is traced when the prior
# never traced its suite, has no entry for it, has an entry that names no
# commit, or has an entry whose commit the diffs do not cover.
#
# Input: the prior map (schema/testing-trace.schema.json), or null, and
#        ahead of it, with --with and in this order: the traceable suites,
#        {<name>: {runner, files}}, and for each commit that a prior entry
#        was traced at, the files that differ between it and this run's
#        commit, {<commit>: [paths]}.
#
#   {suites: {unit: {runner: "bats", tests: {"test/a.bats": {...}}}},
#    work: [{suite: "unit", file: "test/b.bats"}], carried: 1}

function main(line) {
  tree_line(line)
}

# Notes every file that differs from each commit, in DIFFERS[commit, path],
# and every commit the diffs cover, in IS_COVERED.
function read_diffs(__commit, __path) {
  for (__commit = NODE_FIRST[DIFFS]; __commit != 0; __commit = NODE_NEXT[__commit]) {
    IS_COVERED[name_of(__commit)] = 1
    for (__path = NODE_FIRST[__commit]; __path != 0; __path = NODE_NEXT[__path]) {
      DIFFERS[name_of(__commit), text_of(__path)] = 1
    }
  }
}

# Reads every file of every traceable suite into ITEM_SUITE and ITEM_FILE,
# in the byte order of the suites' names and of each suite's files, with
# the prior's entry for it in ITEM_ENTRY and whether that entry holds in
# ITEM_CARRIED.
function read_items(__names, __count, __i, __suite, __files, __file_count, __file, __j) {
  __count = 0
  for (__suite = NODE_FIRST[SUITES]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    __names[++__count] = name_of(__suite)
  }
  sort_texts(__names, __count)

  ITEMS = 0
  for (__i = 1; __i <= __count; __i++) {
    __suite = member(SUITES, __names[__i])
    SORTED_SUITE[++SORTED_SUITES] = __suite

    __file_count = 0
    for (__file = NODE_FIRST[member(__suite, "files")]; __file != 0; __file = NODE_NEXT[__file]) {
      __files[++__file_count] = text_of(__file)
    }
    sort_texts(__files, __file_count)

    for (__j = 1; __j <= __file_count; __j++) {
      read_item(__suite, __files[__j])
    }
  }
}

# Reads one file of a traceable suite as the next item.
function read_item(suite, file) {
  ITEMS++
  ITEM_SUITE[ITEMS] = suite
  ITEM_FILE[ITEMS] = file
  ITEM_ENTRY[ITEMS] = prior_entry(suite, file)
  ITEM_CARRIED[ITEMS] = holds(ITEM_ENTRY[ITEMS], file)
  CARRIED += ITEM_CARRIED[ITEMS]
}

# The prior's entry for a file of a suite, and no node when the prior
# never traced the suite, traced it with another runner, or has no entry
# for the file.
function prior_entry(suite, file, __traced) {
  __traced = member(member(ROOT, "suites"), name_of(suite))
  if (!is_present(__traced) || written(member(__traced, "runner")) != written(member(suite, "runner"))) {
    return 0
  }

  return member(member(__traced, "tests"), file)
}

# Whether a prior entry still holds for its file.
function holds(entry, file, __commit) {
  if (!is_present(entry) || NODE_TYPE[member(entry, "commit")] != "str") {
    return 0
  }

  __commit = text_of(member(entry, "commit"))
  return (__commit in IS_COVERED) \
    && !((__commit, file) in DIFFERS) \
    && !any_differs(__commit, member(entry, "reads")) \
    && !any_differs(__commit, member(entry, "probes"))
}

# Whether any of the paths under a node differs from a commit.
function any_differs(commit, paths, __path) {
  for (__path = NODE_FIRST[paths]; __path != 0; __path = NODE_NEXT[__path]) {
    if ((commit, text_of(__path)) in DIFFERS) {
      return 1
    }
  }

  return 0
}

# Prints the map's suites: for each traceable suite its runner and the
# entries carried forward, each under its file.
function print_suites(__i, __n, __printed) {
  print_open(0, wrap("suites"), "map")

  for (__i = 1; __i <= SORTED_SUITES; __i++) {
    print_open(1, NODE_KEY[SORTED_SUITE[__i]], "map")
    print_node(member(SORTED_SUITE[__i], "runner"), 2, wrap("runner"))
    print_open(2, wrap("tests"), "map")

    for (__n = 1; __n <= ITEMS; __n++) {
      if (ITEM_SUITE[__n] == SORTED_SUITE[__i] && ITEM_CARRIED[__n] && !((__i, ITEM_FILE[__n]) in __printed)) {
        __printed[__i, ITEM_FILE[__n]] = 1
        print_node(ITEM_ENTRY[__n], 3, wrap(ITEM_FILE[__n]))
      }
    }
  }
}

# Prints the files left to trace, each {suite, file}.
function print_work(__n, __printed) {
  print_open(0, wrap("work"), "list")

  __printed = 0
  for (__n = 1; __n <= ITEMS; __n++) {
    if (!ITEM_CARRIED[__n]) {
      print_open(1, __printed++, "map")
      print_str(2, "suite", name_of(ITEM_SUITE[__n]))
      print_str(2, "file", ITEM_FILE[__n])
    }
  }
}

BEGIN {
  SUITES = tree_ahead()
  DIFFS = tree_ahead()
  ROOT = tree_open()
  CARRIED = 0
  SORTED_SUITES = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  read_diffs()
  read_items()
  print_suites()
  print_work()
  print "0." wrap("carried") ":int=" CARRIED
}

{ main($0) }
