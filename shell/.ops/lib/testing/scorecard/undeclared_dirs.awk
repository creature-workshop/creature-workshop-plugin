# Prints the directories under a grouping area's source through which
# tracked files fall to the grouping area itself, as a list of {area,
# path} in the byte order of the areas and then of the paths, each once.
# Loaded after testing.awk.
#
# A grouping area is one with an area declared under it: lib is one when
# lib.git exists. Its source is a level that the areas have divided, so a
# file there that belongs to the grouping area, and not to an area under
# it, is in a module that no area declares, and a change to it runs
# whatever the grouping area runs. The finding is the directory directly
# under the source that has such a file. A file directly in the source is
# not reported, because it belongs to the grouping area. Which area a file
# belongs to is source_area, the rule that selection uses.
#
# Input: the areas (schema/testmap.schema.json), and ahead of them, with
#        --with, the tracked files, paths under the project.

function main(line) {
  tree_line(line)
}

# Notes every grouping area: the parent of every dotted name.
function note_groupers(__area, __name) {
  for (__area = NODE_FIRST[ROOT]; __area != 0; __area = NODE_NEXT[__area]) {
    __name = name_of(__area)
    if (index(__name, ".") > 0) {
      sub(/\.[^.]*$/, "", __name)
      IS_GROUPER[__name] = 1
    }
  }
}

# The first source path of an area that covers a file.
function owning_path(area, file, __path) {
  for (__path = NODE_FIRST[member(member(ROOT, area), "paths")]; __path != 0; __path = NODE_NEXT[__path]) {
    if (covers(text_of(__path), file)) {
      return text_of(__path)
    }
  }

  return ""
}

# The directory directly under a source that has a file, and the empty
# string for a file directly in the source or one that is the source.
function child_directory(source, file, __rest) {
  if (index(file, source "/") != 1) {
    return ""
  }

  __rest = substr(file, length(source) + 2)
  if (index(__rest, "/") == 0) {
    return ""
  }

  return source "/" substr(__rest, 1, index(__rest, "/") - 1)
}

# Notes the directory through which a file falls to a grouping area, when
# it does.
function note_finding(file, __directory) {
  if (!source_area(ROOT, file) || !(SOURCE_AREA in IS_GROUPER)) {
    return
  }

  __directory = child_directory(owning_path(SOURCE_AREA, file), file)
  if (__directory != "") {
    FINDING[++FINDINGS] = SOURCE_AREA "\001" __directory
  }
}

BEGIN {
  TRACKED = tree_ahead()
  ROOT = tree_open()
  FINDINGS = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  note_groupers()
  for (file = NODE_FIRST[TRACKED]; file != 0; file = NODE_NEXT[file]) {
    note_finding(text_of(file))
  }

  FINDINGS = unique_texts(FINDING, FINDINGS)
  for (i = 1; i <= FINDINGS; i++) {
    split(FINDING[i], parts, "\001")
    print_open(0, i - 1, "map")
    print_str(1, "area", parts[1])
    print_str(1, "path", parts[2])
  }
  if (FINDINGS == 0) {
    print "0.:list"
  }
}

{ main($0) }
