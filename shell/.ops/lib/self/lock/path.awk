# Prints the scalar at the dotted path WANT of the lock on stdin, "seeds.doc",
# read by nesting with lib/self/lock/lines.awk, and nothing when the lock
# holds no scalar there. The boot reads the seeds this way, before the
# structs library has loaded. The input is read to its end, so the writer
# on a pipe is never cut off; the first match is the answer.
#
#   awk -v WANT=seeds.doc -f lock_lines.awk -f lock_path.awk .ops/lock

found != 1 && opens_map($0) {
  enter($0)
  next
}

found != 1 && closes_map($0) {
  leave()
  next
}

found != 1 && is_member($0) {
  if ((depth == 0 ? "" : path() ".") key($0) == WANT) {
    answer = value($0)
    found = 1
  }
}

END {
  if (found == 1) {
    print answer
  }
}
