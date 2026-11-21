# The lines of a lock, read by nesting (lib/self/lock/api.sh). The lock is
# pretty JSON with one member per line, so a line is one of: the opening of
# a map, "<key>": {, the closing of one, }, a scalar member, "<key>": <value>,
# or something neither (the root braces, an array's elements). These
# functions tell the kinds apart and read a key and a value off a line, for
# the programs that walk the lock with no JSON reader.

function opens_map(line) {
  return line ~ /^[ \t]*"[^"]*":[ \t]*\{[ \t]*$/
}

function closes_map(line) {
  return line ~ /^[ \t]*\}[ \t]*,?[ \t]*$/
}

function is_member(line) {
  return line ~ /^[ \t]*"[^"]*":/
}

function key(line, __k) {
  __k = line
  sub(/^[ \t]*"/, "", __k)
  sub(/".*$/, "", __k)
  return __k
}

function value(line, __v) {
  __v = line
  sub(/^[^:]*:[ \t]*/, "", __v)
  sub(/[ \t]*,?[ \t]*$/, "", __v)
  if (__v ~ /^"/) {
    __v = substr(__v, 2, length(__v) - 2)
  }
  return __v
}

# Keeps the path of the map the line sits in: enter() on an opening line,
# leave() on a closing one, and path() for the dotted path of the current
# map, "dependencies.imports".
function enter(line) {
  depth++
  names[depth] = key(line)
}

function leave() {
  if (depth > 0) {
    depth--
  }
}

function path(__p, __i) {
  __p = ""
  for (__i = 1; __i <= depth; __i++) {
    __p = __p (__i > 1 ? "." : "") names[__i]
  }
  return __p
}
