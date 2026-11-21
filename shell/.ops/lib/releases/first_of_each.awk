# Prints each distinct line once, at the place it first appears; a line seen
# before is dropped. jq's unique sorts, and the order the history names its
# reviews in is the order the notes keep.

!seen[$0]++ {
  print
}
