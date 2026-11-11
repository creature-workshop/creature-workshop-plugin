# Prints every file that a selection claimed, in byte order with each
# once. Only a selection that is active and confident counts: one whose
# mode is not the shadow mode and whose confidence is not advisory. Loaded
# after testing.awk.
#
# Input: the selections, a list of {id, confidence, mode, claimed}.
# Args:  advisory, the confidence word of a selector that claims nothing
#        by its answer, and shadow, the mode word of a selector whose
#        answer goes into nothing.

function main(line) {
  tree_line(line)
}

# Whether a selection's claims count.
function claims(selection) {
  return text_of(member(selection, "confidence")) != arg("advisory") \
    && text_of(member(selection, "mode")) != arg("shadow")
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  count = 0
  for (selection = NODE_FIRST[ROOT]; selection != 0; selection = NODE_NEXT[selection]) {
    if (!claims(selection)) {
      continue
    }
    for (file = NODE_FIRST[member(selection, "claimed")]; file != 0; file = NODE_NEXT[file]) {
      files[++count] = text_of(file)
    }
  }

  count = unique_texts(files, count)
  if (count == 0) {
    print "0.:list"
  }
  print_texts(files, count, -1)
}

{ main($0) }
