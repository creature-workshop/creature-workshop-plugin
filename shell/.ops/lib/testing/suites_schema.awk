# Prints the schema of the manifest's testing.suites, put together from
# the suite-config fragment of every registered runner. Each suite is one
# value of a union that the runner field tells apart: the union requires
# runner, lists every runner's id as its allowed values, and has one
# branch for each runner, written out in full so that a validator checks
# it wherever the schema is embedded. Loaded after tree_edit.awk and
# testing.awk.
#
# A branch is the runner's fragment with three properties added: discovery,
# whose allowed strategies are the runner's own list, and reach and
# depends_on, which every suite has whatever its runner. The runners are
# taken in the byte order of their ids, so the schema is the same on every
# run and schema/testmap.schema.json can mirror it.
#
# Input: {<runner id>: {schema, discovery}}, where schema is the runner's
#        fragment and discovery is every strategy name that is valid for
#        the runner: "default" and the ones it opted into.

function main(line) {
  tree_line(line)
}

# A new map with a description.
function described(description, __node) {
  __node = new_node("", "map")
  put(__node, "description", "str=" wrap(description))

  return __node
}

# The schema of the discovery property of one runner, whose allowed
# strategies are the list given.
function discovery_property(strategies, __property, __items) {
  __property = new_node("", "map")
  put(__property, "type", "str=" wrap("array"))
  __items = map_under(__property, "items")
  put(__items, "type", "str=" wrap("string"))
  put_node(__items, "enum", strategies)
  put(__property, "description", "str=" wrap("Test-discovery strategies to union. \"default\" expands to the runner's own suite_defaults.discovery; the rest are the strategies this runner supports (resolver-owned \"sibling\"/\"filename\", or runner-specific)."))

  return __property
}

# The schema of the reach property, which says whether a suite's tests
# stay inside their own process tree.
function reach_property(__property, __values) {
  __values[1] = "in_tree"
  __values[2] = "out_of_tree"

  __property = new_node("", "map")
  put_node(__property, "enum", list_of_texts(__values, 2))
  put(__property, "description", "str=" wrap("Whether the suite's tests stay inside their own process tree. in_tree, the default: the trace map records what a test reads, and the trace selector may select by it. out_of_tree: the tests reach a service, a daemon or a container the trace cannot follow, so the trace selector never claims a file for the suite, and the suite runs whole on a change under any of its depends_on areas, or on every change that is not inert when it declares none."))

  return __property
}

# The schema of the depends_on property, which names the areas that an
# out-of-tree suite depends on.
function depends_on_property(__property, __items) {
  __property = new_node("", "map")
  put(__property, "type", "str=" wrap("array"))
  __items = map_under(__property, "items")
  put(__items, "type", "str=" wrap("string"))
  put(__items, "minLength", "int=1")
  put(__property, "description", "str=" wrap("The dotted area names an out_of_tree suite depends on: a change under any of them, or under a nested area of one, selects the whole suite. A declared edge, for a dependency nothing can observe."))

  return __property
}

# The branch of one runner: its fragment with the discovery, reach and
# depends_on properties in it.
function branch_of(runner, __schema, __properties) {
  __schema = member(runner, "schema")
  if (NODE_TYPE[__schema] != "map") {
    __schema = new_node("", "map")
  }

  __properties = map_under(__schema, "properties")
  put_node(__properties, "discovery", discovery_property(member(runner, "discovery")))
  put_node(__properties, "reach", reach_property())
  put_node(__properties, "depends_on", depends_on_property())

  return __schema
}

# Reads the branch of every runner into BRANCH[1..BRANCHES], in the byte
# order of the runners' ids.
function read_branches(__runner, __ids, __i) {
  BRANCHES = 0
  for (__runner = NODE_FIRST[ROOT]; __runner != 0; __runner = NODE_NEXT[__runner]) {
    __ids[++BRANCHES] = name_of(__runner)
  }
  sort_texts(__ids, BRANCHES)

  for (__i = 1; __i <= BRANCHES; __i++) {
    BRANCH[__i] = branch_of(member(ROOT, __ids[__i]))
  }
}

# Prints the union of the branches, under additionalProperties: the base
# that requires runner and lists the allowed ids, and every branch.
function print_union(__i) {
  print_open(0, wrap("additionalProperties"), "map")
  print_str(1, "type", "object")
  print_open(1, wrap("required"), "list")
  print "2.0:str=" wrap("runner")

  print_open(1, wrap("properties"), "map")
  print_open(2, wrap("runner"), "map")
  print_open(3, wrap("enum"), "list")
  for (__i = 1; __i <= BRANCHES; __i++) {
    print_node(member(member(member(BRANCH[__i], "properties"), "runner"), "const"), 4, __i - 1)
  }
  print_str(3, "description", "Framework runner id that executes this suite. Must be one of the registered runners.")

  print_open(1, wrap("oneOf"), "list")
  for (__i = 1; __i <= BRANCHES; __i++) {
    print_node(BRANCH[__i], 2, __i - 1)
  }
  print_str(1, "description", "One test suite. `runner` selects the framework runner; the remaining fields are validated by that runner's contributed fragment.")
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  read_branches()
  print_str(0, "type", "object")
  print_str(0, "description", "Test suites for impacted-test dispatch, keyed by suite name. Each suite's shape is contributed by its framework runner; this block is composed from the registered runners' schema fragments (see lib/testing/adapter.sh testing__suites_schema). Do not hand-edit beyond mirroring that composition.")
  print_union()
}

{ main($0) }
