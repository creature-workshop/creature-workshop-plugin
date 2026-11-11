# Prints the test entries that the areas list and that name nothing in the
# tracked files, as a list of {area, suite, entry}. Loaded after
# testing.awk.
#
# An entry with a glob character is alive when a tracked file matches it
# part by part, the way the shell expands it. Any other entry is alive
# when a tracked file is the entry or is under it, so an entry that names
# a directory of tests counts.
#
# Input: the areas before tests are attached, so that their tests are what
#        the manifest lists, and ahead of them, with --with, the tracked
#        files, paths under the project.

function main(line) {
  tree_line(line)
}

# Reads the tracked files into FILE[1..FILES], and notes each file and
# every directory above it in IS_TRACKED.
function read_files(__file, __above, __count, __i) {
  FILES = 0

  for (__file = NODE_FIRST[TRACKED]; __file != 0; __file = NODE_NEXT[__file]) {
    FILE[++FILES] = text_of(__file)

    __count = ancestors(FILE[FILES], __above)
    for (__i = 1; __i <= __count; __i++) {
      IS_TRACKED[__above[__i]] = 1
    }
  }
}

# Whether a tracked file satisfies an entry.
function is_alive(entry) {
  if (has_glob_chars(entry)) {
    return any_file_matches(entry)
  }

  return entry in IS_TRACKED
}

# Whether any tracked file matches a path glob.
function any_file_matches(glob, __i) {
  for (__i = 1; __i <= FILES; __i++) {
    if (matches_path_glob(FILE[__i], glob)) {
      return 1
    }
  }

  return 0
}

# Prints the dead entries of one area. Returns how many it printed, given
# how many were printed before it.
function print_dead(area, printed, __suite, __entry, __found) {
  __found = 0

  for (__suite = NODE_FIRST[normalized_tests(area)]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    for (__entry = NODE_FIRST[__suite]; __entry != 0; __entry = NODE_NEXT[__entry]) {
      if (!is_alive(text_of(__entry))) {
        print_open(0, printed + __found++, "map")
        print_str(1, "area", name_of(area))
        print_str(1, "suite", name_of(__suite))
        print_str(1, "entry", text_of(__entry))
      }
    }
  }

  return __found
}

BEGIN {
  TRACKED = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  read_files()
  printed = 0
  for (area = NODE_FIRST[ROOT]; area != 0; area = NODE_NEXT[area]) {
    printed += print_dead(area, printed)
  }
  if (printed == 0) {
    print "0.:list"
  }
}

{ main($0) }
