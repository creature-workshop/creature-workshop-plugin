# Prints the notes on a merge request's conversation: the flattened notes
# with no position. A note anchored to a line of the diff belongs to a
# thread.

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

  notes = 0
  for (note = NODE_FIRST[ROOT]; note != 0; note = NODE_NEXT[note]) {
    if (!is_present(member(note, "position"))) {
      print_node(note, 0, notes)
      notes++
    }
  }

  if (notes == 0) {
    print "0.:list"
  }
}

{ main($0) }
