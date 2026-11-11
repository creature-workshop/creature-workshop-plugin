# The coverage report as every coverage runner prints it, so two runners
# cannot print it differently: the metric that the counts count, each file
# under its path with what was covered out of what could be, and the totals
# of the workspace. lib/coverage/api.sh documents the report. It holds
# functions alone. Loaded after tree.awk.
#
#   {metric: "lines",
#    files: {"lib/a.rs": {covered: 3, total: 4, suite: "unit", runner: "tarpaulin"}},
#    totals: {covered: 3, total: 4}}

# A path under the workspace root when it is inside the root, and the path
# unchanged when it is not.
function relative(root, path) {
  return (index(path, root "/") == 1) ? substr(path, length(root) + 2) : path
}

# Adds a file to the report, with the nodes that give what was covered and
# what could be. A path noted twice keeps its place and its last counts.
function note_file(path, covered, total) {
  if (!(path in FILE_AT)) {
    FILE_AT[path] = ++FILES
    FILE_PATH[FILES] = path
  }

  FILE_COVERED[FILE_AT[path]] = covered
  FILE_TOTAL[FILE_AT[path]] = total
}

# Prints the report: the files noted so far, each attributed to the suite
# and the runner that measured it, and the totals from the nodes given.
function print_report(metric, suite, runner, covered, total, __i) {
  print_str(0, "metric", metric)

  print_open(0, wrap("files"), "map")
  for (__i = 1; __i <= FILES; __i++) {
    print_open(1, wrap(FILE_PATH[__i]), "map")
    print_node(FILE_COVERED[__i], 2, wrap("covered"))
    print_node(FILE_TOTAL[__i], 2, wrap("total"))
    print_str(2, "suite", suite)
    print_str(2, "runner", runner)
  }

  print_open(0, wrap("totals"), "map")
  print_node(covered, 1, wrap("covered"))
  print_node(total, 1, wrap("total"))
}
