# Reads a unified diff (`git diff -U0`) on stdin and prints the new-file line
# number of each added line. A hunk header `@@ -a,b +c,d @@` adds the d new-side
# lines starting at c (a single-line hunk omits ,d and adds one line at c).
/^@@/ {
  match($0, /\+[0-9]+(,[0-9]+)?/)
  split(substr($0, RSTART + 1, RLENGTH - 1), parts, ",")
  start = parts[1] + 0
  count = (parts[2] == "" ? 1 : parts[2] + 0)
  for (i = 0; i < count; i++) {
    print start + i
  }
}
