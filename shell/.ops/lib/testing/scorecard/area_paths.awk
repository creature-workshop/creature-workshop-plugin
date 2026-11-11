# Prints every source path that an area declares, as one line of text for
# each: the area's name, a tab, and the path. The check for paths that do
# not exist reads these lines and tests each path in the shell.
#
# Input: the areas (from areas__compute_areas).

function main(line) {
  tree_line(line)
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  for (area = NODE_FIRST[ROOT]; area != 0; area = NODE_NEXT[area]) {
    for (path = NODE_FIRST[member(area, "paths")]; path != 0; path = NODE_NEXT[path]) {
      print name_of(area) "\t" text_of(path)
    }
  }
}

{ main($0) }
