# serialize.awk -- a node back to JSON text: one compact line, insertion
# order kept, number lexemes verbatim.

function json_serialize(id, __out, __i) {
  if (J_TYPE[id] == "object") {
    __out = "{"
    for (__i = 1; __i <= J_N[id]; __i++) {
      if (__i > 1) {
        __out = __out ","
      }
      __out = __out json_encode_string(J_KEY[id, __i]) ":" json_serialize(J_CHILD[id, __i])
    }
    return __out "}"
  }
  if (J_TYPE[id] == "array") {
    return "[" json_serialize_children(id) "]"
  }
  if (J_TYPE[id] == "string") {
    return json_encode_string(J_STR[id])
  }
  return J_RAW[id]
}

# An object's or array's children serialized and comma-joined -- the inside
# of a "[...]".
function json_serialize_children(id) {
  return json_serialize_range(id, 1, J_N[id])
}

# The children from..to serialized and comma-joined -- the inside of a
# slice like "all but the last". An empty range is the empty string.
function json_serialize_range(id, from, to, __out, __i) {
  __out = ""
  for (__i = from; __i <= to; __i++) {
    if (__i > from) {
      __out = __out ","
    }
    __out = __out json_serialize(J_CHILD[id, __i])
  }
  return __out
}

# A decoded-past-ASCII \uXXXX kept by the parser starts with a lone backslash
# followed by u; re-escaping the backslash would corrupt it, so those pass
# through. Everything else follows the JSON string grammar.
function json_encode_string(s, __out, __i, __c) {
  __out = "\""
  __i = 1
  while (__i <= length(s)) {
    __c = substr(s, __i, 1)
    if (__c == "\\" && substr(s, __i + 1, 1) == "u") {
      __out = __out substr(s, __i, 6)
      __i += 6
      continue
    }
    __out = __out json_encode_char(__c)
    __i++
  }
  return __out "\""
}

# One character under the JSON string grammar: specials escaped by name,
# other control characters as \u00XX, everything else itself.
function json_encode_char(c, __code) {
  if (c == "\\") {
    return "\\\\"
  }
  if (c == "\"") {
    return "\\\""
  }
  if (c == "\n") {
    return "\\n"
  }
  if (c == "\t") {
    return "\\t"
  }
  if (c == "\r") {
    return "\\r"
  }
  if (c == "\b") {
    return "\\b"
  }
  if (c == "\f") {
    return "\\f"
  }
  __code = json_ord(c)
  if (__code < 32) {
    return sprintf("\\u%04x", __code)
  }
  return c
}

# What jq -r prints for a node: strings decoded, everything else its JSON.
# An absent node (-1) is jq's null.
function json_print_raw(id) {
  if (id < 0 || J_TYPE[id] == "null") {
    return "null"
  }
  if (J_TYPE[id] == "string") {
    return J_STR[id]
  }
  return json_serialize(id)
}
