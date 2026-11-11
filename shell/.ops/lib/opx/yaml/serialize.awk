# serialize.awk -- a value in the structs node table printed as a YAML
# document in block style. Loaded after the structs JSON runtime and
# scalars.awk. A mapping's keys keep their order, a nested collection is
# indented by two, and an empty one is written "{}" or "[]". A string is
# written plain only where it reads back as the same string, as a literal
# block when it runs over lines, and in double quotes, as JSON spells it,
# everywhere else.
#
#   {"jobs":[{"name":"test","needs":[]}],"on":"push"}
#
#   jobs:
#     - name: test
#       needs: []
#   "on": push

# n spaces.
function yaml_spaces(n) {
  return sprintf("%" n "s", "")
}

# A string as YAML writes it, as a key or as a value.
function yaml_string_text(text) {
  if (yaml_is_plain_safe(text)) {
    return text
  }
  return json_encode_string(text)
}

# Whether the node is written on its key's or its dash's own line: a scalar,
# or a collection that holds nothing.
function yaml_is_inline(id) {
  return (J_TYPE[id] != "object" && J_TYPE[id] != "array") || J_N[id] == 0
}

# The text of a node that is written on one line.
function yaml_inline_text(id) {
  if (J_TYPE[id] == "object") {
    return "{}"
  }
  if (J_TYPE[id] == "array") {
    return "[]"
  }
  if (J_TYPE[id] == "string") {
    return yaml_string_text(J_STR[id])
  }
  return J_RAW[id]
}

# The mark that opens a literal block holding text: "|-" when the text ends
# with no line break, "|+" when it ends with several, "|" for the one.
function yaml_block_header(text) {
  if (text !~ /\n$/) {
    return "|-"
  }
  return (text ~ /\n\n$/) ? "|+" : "|"
}

# Prints a string as a literal block after lead, its lines at indent.
function yaml_write_literal(lead, text, indent, __n, __i, __lines) {
  print lead yaml_block_header(text)
  sub(/\n$/, "", text)
  __n = split(text, __lines, "\n")
  for (__i = 1; __i <= __n; __i++) {
    print (__lines[__i] == "") ? "" : yaml_spaces(indent) __lines[__i]
  }
}

# Prints, after lead, a node that needs no block of its own: on lead's line,
# or for a string that runs over lines as a literal block under it.
function yaml_write_inline(lead, id, indent) {
  if (J_TYPE[id] == "string" && yaml_is_block_safe(J_STR[id])) {
    yaml_write_literal(lead, J_STR[id], indent)
    return
  }
  print lead yaml_inline_text(id)
}

# Prints one member of a mapping after lead, its value on the same line or
# as a block indented past indent.
function yaml_write_member(lead, key, child, indent) {
  if (yaml_is_inline(child)) {
    yaml_write_inline(lead yaml_string_text(key) ": ", child, indent + 2)
    return
  }
  print lead yaml_string_text(key) ":"
  yaml_write_block(child, indent + 2, "")
}

# Prints a mapping whose keys sit at indent. The first key follows first
# when it is given, which is how a mapping opens on a sequence's dash.
function yaml_write_mapping(id, indent, first, __i) {
  for (__i = 1; __i <= J_N[id]; __i++) {
    yaml_write_member((__i == 1 && first != "") ? first : yaml_spaces(indent), J_KEY[id, __i], J_CHILD[id, __i], indent)
  }
}

# Prints one element of a sequence after lead, which ends in its dash.
function yaml_write_item(lead, child, indent) {
  if (yaml_is_inline(child)) {
    yaml_write_inline(lead, child, indent + 2)
    return
  }
  yaml_write_block(child, indent + 2, lead)
}

# Prints a sequence whose dashes sit at indent, the first following first
# when it is given.
function yaml_write_sequence(id, indent, first, __i) {
  for (__i = 1; __i <= J_N[id]; __i++) {
    yaml_write_item(((__i == 1 && first != "") ? first : yaml_spaces(indent)) "- ", J_CHILD[id, __i], indent)
  }
}

# Prints a collection that holds something, at indent.
function yaml_write_block(id, indent, first) {
  if (J_TYPE[id] == "object") {
    yaml_write_mapping(id, indent, first)
  } else {
    yaml_write_sequence(id, indent, first)
  }
}

# Prints the value at node id as a whole YAML document.
function yaml_write_doc(id) {
  if (yaml_is_inline(id)) {
    yaml_write_inline("", id, 2)
    return
  }
  yaml_write_block(id, 0, "")
}
