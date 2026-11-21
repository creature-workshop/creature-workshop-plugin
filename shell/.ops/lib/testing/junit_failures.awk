# junit_failures.awk -- the test files a junit report marks failed, one per
# line, deduplicated across reports on the same stream.
#
# classname is read as written: the join key is the runner's spelling, and the
# report's writer owes the escape key its contract (a repo-relative file under
# file-path). A passing testcase is self-closing and never reaches the failure
# rule; a failing one carries a <failure> or <error> child before its
# </testcase>.

/<testcase / {
  current = $0
  sub(/.*classname="/, "", current)
  sub(/".*/, "", current)
}

/<(failure|error)[ >]/ {
  if (current != "" && !(current in seen)) {
    seen[current] = 1
    print current
  }
}
