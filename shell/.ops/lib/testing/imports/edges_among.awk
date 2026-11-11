# Prints the edges every provider read that join two tracked files: an edge
# whose target git does not track, or a file's load of itself, is left
# out. Loaded after testing.awk and edges.awk.
#
# Input: the providers' edges, a list of {from, to}, and ahead of it, with
#        --with, the tracked files, paths under the project.

function main(line) {
  tree_line(line)
}

# Notes every tracked file.
function note_tracked(__file) {
  for (__file = NODE_FIRST[TRACKED]; __file != 0; __file = NODE_NEXT[__file]) {
    IS_TRACKED[text_of(__file)] = 1
  }
}

# Notes every edge that ends at a tracked file other than the one it
# starts at.
function note_edges_among(__edge, __from, __to) {
  for (__edge = NODE_FIRST[ROOT]; __edge != 0; __edge = NODE_NEXT[__edge]) {
    __from = text_of(member(__edge, "from"))
    __to = text_of(member(__edge, "to"))
    if ((__to in IS_TRACKED) && __from != __to) {
      note_edge(__from, __to)
    }
  }
}

BEGIN {
  TRACKED = tree_ahead()
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  note_tracked()
  note_edges_among()
  print_edges()
}

{ main($0) }
