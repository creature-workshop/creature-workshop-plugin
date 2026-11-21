# newest_noted.awk -- the first commit of a history that carries a note.
#
# Input: the commits carrying a note, one per line, then the history newest
# first (git rev-list). Prints the first line of the history that is among
# the noted commits, or nothing. The history is read to its end rather than
# left early, so the writer on the other side of the pipe is never cut off.

# The first input file: the noted commits.
FNR == NR {
  noted[$0] = 1
  next
}

!found && ($0 in noted) {
  found = $0
}

END {
  if (found != "") {
    print found
  }
}
