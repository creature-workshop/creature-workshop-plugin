# Prints the resolver with a need recorded among a tool's needs, and as it
# is when the need is already there. Loaded after resolver.awk.
#
# Input: the resolver. Arguments "tool" and "need".

function main(line) {
  tree_line(line)
}

# Whether the tool already has the need.
function has_need(__need) {
  for (__need = NODE_FIRST[member(member(member(ROOT, "registry"), arg("tool")), "needs")]; __need != 0; __need = NODE_NEXT[__need]) {
    if (text_of(__need) == arg("need")) {
      return 1
    }
  }

  return 0
}

# Prints the registry with the need added to the tool, and the tool added
# after the others when the registry does not name it.
function print_registry(depth, __tool, __found) {
  print_open(depth, wrap("registry"), "map")
  __found = 0

  for (__tool = NODE_FIRST[member(ROOT, "registry")]; __tool != 0; __tool = NODE_NEXT[__tool]) {
    if (name_of(__tool) == arg("tool")) {
      print_open(depth + 1, NODE_KEY[__tool], "map")
      print_fields_with_need(__tool, depth + 2)
      __found = 1
    } else {
      print_node(__tool, depth + 1, NODE_KEY[__tool])
    }
  }

  if (!__found) {
    print_open(depth + 1, wrap(arg("tool")), "map")
    print_needs(0, depth + 2)
  }
}

# Prints the fields of a tool with the need added to its needs: where the
# tool has needs, and after its other fields when it has none.
function print_fields_with_need(tool, depth, __field, __printed) {
  __printed = 0

  for (__field = NODE_FIRST[tool]; __field != 0; __field = NODE_NEXT[__field]) {
    if (NODE_KEY[__field] == wrap("needs")) {
      print_needs(__field, depth)
      __printed = 1
    } else {
      print_node(__field, depth, NODE_KEY[__field])
    }
  }

  if (!__printed) {
    print_needs(0, depth)
  }
}

# Prints the needs a tool has, and the new need after them.
function print_needs(needs, depth, __need, __count) {
  print_open(depth, wrap("needs"), "list")

  __count = 0
  for (__need = NODE_FIRST[needs]; __need != 0; __need = NODE_NEXT[__need]) {
    print_node(__need, depth + 1, __count)
    __count++
  }
  print (depth + 1) "." __count ":str=" wrap(arg("need"))
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  if (has_need()) {
    print_document(ROOT)
  } else {
    print_resolver(ROOT, 0)
  }
}

{ main($0) }
