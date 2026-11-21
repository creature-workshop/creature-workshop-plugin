# Reads a unified diff made with no context lines (`git diff -U0`) on stdin
# and prints the number each added line has in the new file, one per line.
#
# A hunk header `@@ -a,b +c,d @@` adds d lines that start at line c. A
# header with no `,d` adds one line, and `+c,0` adds none.

function main(line, __span, __parts, __start, __count, __i) {
  match(line, /\+[0-9]+(,[0-9]+)?/)
  __span = substr(line, RSTART + 1, RLENGTH - 1)
  split(__span, __parts, ",")
  __start = __parts[1] + 0
  __count = added_count(__parts[2])
  for (__i = 0; __i < __count; __i++) {
    print __start + __i
  }
}

# The number of lines a hunk adds, from the count its header gives; a header
# with no count adds one line.
function added_count(given) {
  if (given == "") {
    return 1
  }
  return given + 0
}

/^@@/ { main($0) }
