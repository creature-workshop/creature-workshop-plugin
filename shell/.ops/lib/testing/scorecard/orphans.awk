# Prints the orphan tests of each suite: the files under the suite's root
# that match the suite's patterns and that no area lists among its tests
# for that suite, as a map of suite to files in byte order. A suite with
# no root and a suite with no orphan are left out. Loaded after
# testing.awk.
#
# A suite's files are the tracked files under its root that discovery may
# list, whose base name matches its glob and not its exclude. An area
# lists a file when it has the file as an entry, or has an entry with a
# glob character that the file matches part by part.
#
# Input: the attached areas, with every area's tests filled in, and ahead
#        of them, with --with and in this order: the tracked files, paths
#        under the project, and the effective suites, {<suite>: {root,
#        glob, exclude}}.

function main(line) {
  tree_line(line)
}

# Notes what the areas list for every suite: each entry in
# IS_LISTED[suite, entry], and each entry with a glob character also in
# LISTED_GLOB[suite, 1..LISTED_GLOBS[suite]].
function read_listed(__area, __suite, __entry, __name) {
  for (__area = NODE_FIRST[ROOT]; __area != 0; __area = NODE_NEXT[__area]) {
    for (__suite = NODE_FIRST[normalized_tests(__area)]; __suite != 0; __suite = NODE_NEXT[__suite]) {
      __name = name_of(__suite)
      for (__entry = NODE_FIRST[__suite]; __entry != 0; __entry = NODE_NEXT[__entry]) {
        IS_LISTED[__name, text_of(__entry)] = 1
        if (has_glob_chars(text_of(__entry))) {
          LISTED_GLOB[__name, ++LISTED_GLOBS[__name]] = text_of(__entry)
        }
      }
    }
  }
}

# Whether an area lists a file for a suite.
function is_listed(suite, file, __i) {
  if ((suite, file) in IS_LISTED) {
    return 1
  }

  for (__i = 1; __i <= LISTED_GLOBS[suite]; __i++) {
    if (matches_path_glob(file, LISTED_GLOB[suite, __i])) {
      return 1
    }
  }

  return 0
}

# Whether a name matches a suite's patterns, which are a list of globs or
# one glob as a str.
function matches_patterns(name, patterns) {
  if (NODE_TYPE[patterns] == "str") {
    return glob_matches(name, text_of(patterns))
  }

  return NODE_TYPE[patterns] == "list" && matches_any(name, patterns)
}

# Whether a tracked file is one of a suite's files.
function is_suite_file(suite, root, file) {
  return discoverable(file) \
    && covers(root, file) \
    && matches_patterns(base_name(file), member(suite, "glob")) \
    && !matches_patterns(base_name(file), member(suite, "exclude"))
}

# Prints the orphans of one suite under its name, and nothing for a suite
# with no root or no orphan. Returns whether it printed.
function print_orphans(suite, __root, __file, __orphans, __count) {
  __root = text_or(member(suite, "root"), "")
  if (__root == "") {
    return 0
  }

  __count = 0
  for (__file = NODE_FIRST[TRACKED]; __file != 0; __file = NODE_NEXT[__file]) {
    if (is_suite_file(suite, __root, text_of(__file)) && !is_listed(name_of(suite), text_of(__file))) {
      __orphans[++__count] = text_of(__file)
    }
  }
  if (__count == 0) {
    return 0
  }

  print_open(0, NODE_KEY[suite], "list")
  print_texts(__orphans, unique_texts(__orphans, __count), 0)
  return 1
}

BEGIN {
  TRACKED = tree_ahead()
  SUITES = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  read_listed()
  printed = 0
  for (suite = NODE_FIRST[SUITES]; suite != 0; suite = NODE_NEXT[suite]) {
    printed += print_orphans(suite)
  }
  if (printed == 0) {
    print "0.:map"
  }
}

{ main($0) }
