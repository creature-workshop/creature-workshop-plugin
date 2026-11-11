# Prints the notes in the threads on a merge request's diff: the flattened
# notes with a position, which is the line each is anchored to.

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
    if (is_present(member(note, "position"))) {
      print_node(note, 0, notes)
      notes++
    }
  }

  if (notes == 0) {
    print "0.:list"
  }
}

{ main($0) }
