# Prints the registry's tools in dependency order, every tool after the
# tools it needs, as {order}. Prints {error} when the walk meets a circular
# dependency or a need the registry does not name, naming the first it
# meets. Loaded after names.awk.
#
# Input: the registry, a map of tool to entry.
#
# The walk is depth-first from each tool in the order of the names. A tool
# already visited adds nothing, one still being walked is a cycle, and any
# other visits what it needs before itself. Once an error is set, nothing
# more is walked.

function main(line) {
  tree_line(line)
}

# Walks one tool: each of its needs in the order the registry lists them,
# and then the tool itself.
function visit(tool, __need) {
  if (ERROR != "" || (tool in VISITED)) {
    return
  }
  if (tool in WALKING) {
    ERROR = "Circular dependency detected involving '" tool "'"
    return
  }

  WALKING[tool] = 1
  for (__need = NODE_FIRST[member(member(ROOT, tool), "needs")]; __need != 0; __need = NODE_NEXT[__need]) {
    visit_need(tool, text_of(__need))
  }
  if (ERROR != "") {
    return
  }

  delete WALKING[tool]
  VISITED[tool] = 1
  ORDERED++
  ORDER[ORDERED] = tool
}

# Walks one need of a tool, refused when the registry does not name it.
function visit_need(tool, need) {
  if (ERROR != "") {
    return
  }
  if (member(ROOT, need) == 0) {
    ERROR = "Tool '" tool "' needs '" need "', which is not registered"
    return
  }

  visit(need)
}

BEGIN {
  ROOT = tree_open()
  ERROR = ""
  ORDERED = 0
}

END {
  if (REFUSED) {
    exit 1
  }

  count = sorted_names(ROOT, tools)
  for (i = 1; i <= count; i++) {
    visit(tools[i])
  }

  if (ERROR != "") {
    print_str(0, "error", ERROR)
    exit 0
  }

  print_open(0, wrap("order"), "list")
  for (i = 1; i <= ORDERED; i++) {
    print "1." (i - 1) ":str=" wrap(ORDER[i])
  }
}

{ main($0) }
