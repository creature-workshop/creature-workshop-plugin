# read_tree.awk -- an OPX document, laid out as mapping.awk says, read a
# line at a time into the structs node table. Shared by every translator out
# of OPX. The root's role is not part of the value and is dropped. Loaded
# after the structs JSON runtime, lines.awk and mapping.awk. Dies, naming
# the line, on one that is no node, that sits deeper than its place in the
# tree allows or under a leaf, that repeats a key of its object, or that
# mixes an array's items with an object's members.
#
# A program calls opx_read_line on every line and opx_read_root once they are
# all read. While reading, OPEN[depth] is the node the lines at depth+1
# attach to, and OPEN_IS_LEAF[depth] whether that node is a leaf, which
# takes no children.

# Dies naming the line that cannot be read.
function refuse(why) {
  printf "opx: line %d: %s: %s\n", NR, why, $0 > "/dev/stderr"
  FAILED = 1
  exit 3
}

# A fresh node holding a bare scalar as the document wrote it.
function literal_node(type, lexeme, __id) {
  __id = json_new(type)
  J_RAW[__id] = lexeme
  return __id
}

# The JSON node a leaf line holds.
function leaf_node(line, __type) {
  __type = opx_type(line)
  if (__type == "string") {
    return json_string_node(opx_value(line))
  }
  if (__type == "int" || __type == "number") {
    return literal_node("number", opx_value(line))
  }
  if (__type == "bool") {
    return literal_node("boolean", opx_value(line))
  }
  if (__type == "null") {
    return json_null_node()
  }
  if (__type == "object" || __type == "array") {
    return json_new(__type)
  }
  refuse("a leaf of a type the mapping does not know")
}

# The JSON node a line holds: a leaf's value, or an object for a composite,
# which becomes an array when its first child is an item.
function line_node(line) {
  if (opx_is_leaf(line)) {
    return leaf_node(line)
  }
  return json_new("object")
}

# Whether the line is an element of an array: its role is the bare one an
# array keeps. Quoted, the same text is an object's key.
function is_item(line) {
  return !opx_role_is_quoted(line) && opx_role(line) == opx_item_role()
}

# Attaches node to parent as its next element, which makes the parent an
# array. Dies when the parent already holds a member.
function attach_item(parent, node) {
  if (J_N[parent] > 0 && J_TYPE[parent] != "array") {
    refuse("an item beside an object's members")
  }
  J_TYPE[parent] = "array"
  json_array_append(parent, node)
}

# Attaches node to parent under key. Dies when the parent holds items, or
# already holds the key.
function attach_member(parent, key, node) {
  if (J_TYPE[parent] == "array") {
    refuse("a member beside an array's items")
  }
  if ((parent, key) in MEMBER_READ) {
    refuse("a key its object already holds")
  }
  MEMBER_READ[parent, key] = 1
  json_object_append(parent, key, node)
}

# Attaches the line's node under parent: as an element or as a member.
function attach(parent, line, node) {
  if (is_item(line)) {
    attach_item(parent, node)
  } else {
    attach_member(parent, opx_role(line), node)
  }
}

# Reads a line: a node attached under the one open above it.
function read_node(line, depth, __node) {
  __node = line_node(line)
  if (depth == 0) {
    ROOT = __node
  } else {
    attach(OPEN[depth - 1], line, __node)
  }
  OPEN[depth] = __node
  OPEN_IS_LEAF[depth] = opx_is_leaf(line)
}

# Reads one line into the tree.
function opx_read_line(line, __depth) {
  if (!opx_is_node(line)) {
    refuse("not an OPX node")
  }
  __depth = opx_depth(line)
  if ((LINES_READ == 0) != (__depth == 0) || __depth > DEEPEST + 1) {
    refuse("out of place in the tree")
  }
  if (__depth > 0 && OPEN_IS_LEAF[__depth - 1]) {
    refuse("under a leaf, which takes no children")
  }
  DEEPEST = __depth
  LINES_READ++
  read_node(line, __depth)
}

# The node the document's root holds. Dies when no line was read.
function opx_read_root() {
  if (FAILED) {
    exit 3
  }
  if (LINES_READ == 0) {
    printf "opx: an empty document holds no value\n" > "/dev/stderr"
    exit 3
  }
  return ROOT
}
