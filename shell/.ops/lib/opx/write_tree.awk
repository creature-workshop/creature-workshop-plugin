# write_tree.awk -- a value in the structs node table printed as an OPX
# document, laid out as mapping.awk says. Shared by every translator into
# OPX, so a value reads the same whatever it was written in. Loaded after
# the structs JSON runtime, emit.awk and mapping.awk.
#
#   opx_write_tree(id, "value")  ->  xK_mQ 0.value
#                                    Lp3qR 1.a
#                                    d1E02 2.item:int.1

# The OPX type of a number: "int" when it is written as one.
function number_type(lexeme) {
  if (lexeme ~ /^-?[0-9]+$/) {
    return "int"
  }
  return "number"
}

# Dies naming the key an object holds twice.
function refuse_repeated_key(key) {
  printf "opx: an object holds the key %s twice\n", opx_quote(key) > "/dev/stderr"
  exit 3
}

# The role an object member is written under: its key, quoted unless the
# mapping writes it bare.
function member_role(key) {
  if (opx_key_is_bare(key)) {
    return key
  }
  return opx_quote(key)
}

# Prints one object member under its key. Dies on a key the object has
# already held.
function emit_member(id, key, child, depth) {
  if ((id, key) in MEMBER_WRITTEN) {
    refuse_repeated_key(key)
  }
  MEMBER_WRITTEN[id, key] = 1
  emit_value(child, depth, member_role(key))
}

# Prints an object: its members in the order the document had them.
function emit_object(id, depth, role, __i) {
  if (J_N[id] == 0) {
    opx_emit_leaf(depth, role, "object", "empty")
    return
  }
  opx_emit_composite(depth, role)
  for (__i = 1; __i <= J_N[id]; __i++) {
    emit_member(id, J_KEY[id, __i], J_CHILD[id, __i], depth + 1)
  }
}

# Prints an array: one item per element.
function emit_array(id, depth, role, __i) {
  if (J_N[id] == 0) {
    opx_emit_leaf(depth, role, "array", "empty")
    return
  }
  opx_emit_composite(depth, role)
  for (__i = 1; __i <= J_N[id]; __i++) {
    emit_value(J_CHILD[id, __i], depth + 1, opx_item_role())
  }
}

# Prints a number, a boolean or a null, its text as the document wrote it.
function emit_literal(id, depth, role) {
  if (J_TYPE[id] == "number") {
    opx_emit_leaf(depth, role, number_type(J_RAW[id]), J_RAW[id])
  } else if (J_TYPE[id] == "boolean") {
    opx_emit_leaf(depth, role, "bool", J_RAW[id])
  } else {
    opx_emit_leaf(depth, role, "null", "null")
  }
}

# Prints the node id, and everything under it, at depth under role.
function emit_value(id, depth, role) {
  if (J_TYPE[id] == "object") {
    emit_object(id, depth, role)
  } else if (J_TYPE[id] == "array") {
    emit_array(id, depth, role)
  } else if (J_TYPE[id] == "string") {
    opx_emit_leaf(depth, role, "string", J_STR[id])
  } else {
    emit_literal(id, depth, role)
  }
}

# Prints the value at node id as a whole document, its root under role, or
# under "value" when role is empty.
function opx_write_tree(id, role) {
  emit_value(id, 0, role == "" ? opx_value_role() : role)
}
