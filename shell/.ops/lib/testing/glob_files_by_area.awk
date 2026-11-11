# Prints the test files of each area: the files that discovery may list and
# whose base name matches one of the globs and none of the excludes, under
# every area that has one of the file's directories, or the file itself,
# among its paths. Each area's files are in byte order and each once. An
# area with no such file is left out. Loaded after testing.awk.
#
# Input: the files, and ahead of them, with --with and in this order: the
#        globs, the excludes, and a map of area to its paths.

function main(line) {
  tree_line(line)
}

# Notes which areas declare each path, in the order the areas declare
# them, with a newline after each area's name.
function note_areas_by_path(__area, __path) {
  for (__area = NODE_FIRST[AREAS]; __area != 0; __area = NODE_NEXT[__area]) {
    for (__path = NODE_FIRST[__area]; __path != 0; __path = NODE_NEXT[__path]) {
      AREAS_AT[text_of(__path)] = AREAS_AT[text_of(__path)] name_of(__area) "\n"
    }
  }
}

# Files one file under every area that declares the file or a directory
# above it, the outermost directory first.
function file_under_areas(file, __above, __count, __i, __names, __areas, __j) {
  __count = ancestors(file, __above)

  for (__i = 1; __i <= __count; __i++) {
    __areas = split(AREAS_AT[__above[__i]], __names, "\n")
    for (__j = 1; __j < __areas; __j++) {
      file_under(__names[__j], file)
    }
  }
}

# Adds a file to an area's files, noting the area the first time it gets
# one.
function file_under(area, file) {
  if (!(area in FILES_OF)) {
    FILED++
    FILED_AREA[FILED] = area
  }
  FILES_OF[area] = FILES_OF[area] file "\n"
}

BEGIN {
  GLOBS = tree_ahead()
  EXCLUDES = tree_ahead()
  AREAS = tree_ahead()
  ROOT = tree_open()
  FILED = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  note_areas_by_path()
  for (file = NODE_FIRST[ROOT]; file != 0; file = NODE_NEXT[file]) {
    path = text_of(file)
    if (discoverable(path) && matching(path, GLOBS, EXCLUDES)) {
      file_under_areas(path)
    }
  }

  for (i = 1; i <= FILED; i++) {
    count = split(FILES_OF[FILED_AREA[i]], files, "\n") - 1
    print_open(0, wrap(FILED_AREA[i]), "list")
    print_texts(files, unique_texts(files, count), 0)
  }

  if (FILED == 0) {
    print "0.:map"
  }
}

{ main($0) }
