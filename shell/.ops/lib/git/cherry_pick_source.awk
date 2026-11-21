# Prints the commit a cherry-pick -x trailer names, read from a commit message
# on stdin: the last such line when a commit was picked more than once, and
# nothing when the message carries none.

/^[[:space:]]*\(cherry picked from commit [0-9a-f]+\)[[:space:]]*$/ {
  line = $0
  sub(/^[[:space:]]*\(cherry picked from commit /, "", line)
  sub(/\)[[:space:]]*$/, "", line)
  source = line
}

END {
  if (source != "") {
    print source
  }
}
