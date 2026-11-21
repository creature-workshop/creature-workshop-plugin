# Prints each area's candidate files that a cargo package owns, as a map
# of area to files. A package owns a file when one of the directories
# above the file is a package root, and a root of "." owns every file. A
# file that no package owns is left out of its area. Loaded after
# testing.awk.
#
# Input: the candidate Rust sources of each area, {<area>: [<file>, ...]},
#        and ahead of it, with --with, the directories whose Cargo.toml
#        declares a package, [<dir>, ...].

function main(line) {
  tree_line(line)
}

# Notes every package root.
function note_package_roots(__root) {
  for (__root = NODE_FIRST[PACKAGE_ROOTS]; __root != 0; __root = NODE_NEXT[__root]) {
    IS_PACKAGE_ROOT[text_of(__root)] = 1
  }
}

# Whether a package owns a file: the file, or a directory above it, is a
# package root.
function owned(file, __above, __count, __i) {
  if ("." in IS_PACKAGE_ROOT) {
    return 1
  }

  __count = ancestors(file, __above)
  for (__i = 1; __i <= __count; __i++) {
    if (__above[__i] in IS_PACKAGE_ROOT) {
      return 1
    }
  }

  return 0
}

# Prints the files of one area that a package owns, under the area's key.
function print_owned(area, __file, __files, __count) {
  __count = 0

  for (__file = NODE_FIRST[area]; __file != 0; __file = NODE_NEXT[__file]) {
    if (owned(text_of(__file))) {
      __files[++__count] = text_of(__file)
    }
  }

  print_open(0, NODE_KEY[area], "list")
  print_texts(__files, __count, 0)
}

BEGIN {
  PACKAGE_ROOTS = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  note_package_roots()
  for (area = NODE_FIRST[ROOT]; area != 0; area = NODE_NEXT[area]) {
    print_owned(area)
  }
  if (NODE_FIRST[ROOT] == 0) {
    print "0.:map"
  }
}

{ main($0) }
