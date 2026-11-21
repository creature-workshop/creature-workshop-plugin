# runtime.awk -- how an awk-backend op run starts, ends, and dies.
#
# The engine is a set of DEFS-ONLY libraries (awk has no include; the runner
# in lib/structs/backend_awk.sh names them all with repeated -f): this file,
# then nodes.awk, parse.awk, serialize.awk, paths.awk and ops.awk, followed
# by one op program. Arguments reach ops through ENVIRON (SP_* names), never
# -v, which rewrites backslash escapes.

# Parse failures set J_ERR rather than exiting, so is_valid can answer false
# where every other op treats broken input as fatal via json_must.
function json_fail(msg) {
  J_ERR = msg
  return -1
}

function json_must(id) {
  if (id < 0) {
    printf "structs/awk: %s\n", J_ERR > "/dev/stderr"
    exit 3
  }
  return id
}

# The document the op's input rule accumulated into J_BUF, minus the one
# trailing newline that rule adds beyond it.
function json_buf() {
  sub(/\n$/, "", J_BUF)
  return J_BUF
}

# The code point of an ASCII character (128 for anything beyond ASCII).
function json_ord(c, __i) {
  if (J_ORD_READY != 1) {
    for (__i = 1; __i < 128; __i++) {
      J_ORD[sprintf("%c", __i)] = __i
    }
    J_ORD_READY = 1
  }
  return (c in J_ORD) ? J_ORD[c] : 128
}
