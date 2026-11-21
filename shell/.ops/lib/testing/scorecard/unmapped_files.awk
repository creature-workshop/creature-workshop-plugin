# Prints the tracked source files that no area covers, in byte order, and
# how many of them are under each first part of a path, so that a report
# can name directories and not every file. Loaded after testing.awk.
#
# A file is unmapped when no area's source path covers it and it is not
# under the root of a suite. The files under a suite's root are tests, and
# whether an area lists each of those is what the orphan check reports, so
# a test is never reported here as well.
#
# Input: the areas (schema/testmap.schema.json), and ahead of them, with
#        --with and in this order: the tracked files, paths under the
#        project, and the effective suites, {<suite>: {root}}.
#
#   {files: ["README.md", "tools/a.sh", "tools/b.sh"],
#    top_level: {"README.md": 1, tools: 2}}

function main(line) {
  tree_line(line)
}

# Notes every path that takes a file out of the report: the source paths
# of the areas and the roots of the suites.
function note_covering_paths(__area, __path, __suite, __root) {
  for (__area = NODE_FIRST[ROOT]; __area != 0; __area = NODE_NEXT[__area]) {
    for (__path = NODE_FIRST[member(__area, "paths")]; __path != 0; __path = NODE_NEXT[__path]) {
      COVERS[text_of(__path)] = 1
    }
  }
  for (__suite = NODE_FIRST[SUITES]; __suite != 0; __suite = NODE_NEXT[__suite]) {
    __root = member(__suite, "root")
    if (is_truthy(__root)) {
      COVERS[text_of(__root)] = 1
    }
  }
}

# Whether a file, or a directory above it, is one of the covering paths.
function is_covered(file, __above, __count, __i) {
  __count = ancestors(file, __above)
  for (__i = 1; __i <= __count; __i++) {
    if (__above[__i] in COVERS) {
      return 1
    }
  }

  return 0
}

# The first part of a path: test/foo.bats is test, and README.md is
# README.md.
function top_part(path) {
  sub(/\/.*$/, "", path)

  return path
}

# Prints how many of the unmapped files are under each first part, in the
# order the parts first occur.
function print_top_level(files, count, __i, __part, __parts, __part_count, __under) {
  __part_count = 0
  for (__i = 1; __i <= count; __i++) {
    __part = top_part(files[__i])
    if (!(__part in __under)) {
      __parts[++__part_count] = __part
    }
    __under[__part]++
  }

  print_open(0, wrap("top_level"), "map")
  for (__i = 1; __i <= __part_count; __i++) {
    print "1." wrap(__parts[__i]) ":int=" __under[__parts[__i]]
  }
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

  note_covering_paths()
  count = 0
  for (file = NODE_FIRST[TRACKED]; file != 0; file = NODE_NEXT[file]) {
    if (!is_covered(text_of(file))) {
      unmapped[++count] = text_of(file)
    }
  }
  sort_texts(unmapped, count)

  print_open(0, wrap("files"), "list")
  print_texts(unmapped, count, 0)
  print_top_level(unmapped, count)
}

{ main($0) }
