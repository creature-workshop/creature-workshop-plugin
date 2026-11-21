# How many times each program started and its share of every start, as one
# struct array, most started first:
#
#   [{"program":"jq","starts":478,"share":69.9},{"program":"grep","starts":113,"share":16.5}]

# The text of s as a JSON string, quotes and backslashes escaped.
function json_string(s) {
  gsub(/\\/, "\\\\", s)
  gsub(/"/, "\\\"", s)
  return "\"" s "\""
}

# One row of the array for program p.
function row(p) {
  return sprintf("{\"program\":%s,\"starts\":%d,\"share\":%.1f}", json_string(p), started[p], 100 * started[p] / execs)
}

# Fills order[1..n] with the programs, most started first, and returns n.
function sort_by_starts(order, __n, __p, __i, __j) {
  __n = 0
  for (__p in started) {
    __i = ++__n
    while (__i > 1 && started[order[__i - 1]] < started[__p]) {
      order[__i] = order[__i - 1]
      __i--
    }
    order[__i] = __p
  }
  return __n
}

is_exec($0) {
  started[exec_program($0)]++
  execs++
}

END {
  n = sort_by_starts(order)
  out = "["
  for (i = 1; i <= n; i++) {
    out = out (i > 1 ? "," : "") row(order[i])
  }
  print out "]"
}
