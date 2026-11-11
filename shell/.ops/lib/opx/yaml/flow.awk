# flow.awk -- a YAML flow collection written on one line, "[a, b]" or
# "{a: 1, b: [x]}", read into the node table. F_TEXT is the text being read
# and F_POS the character the reader stands on. Loaded after lines.awk and
# scalars.awk. One that runs over lines is refused.
#
#   yaml_flow_node("[a, {b: 1}]")  ->  the node of ["a", {"b": 1}]

# Steps over spaces.
function flow_skip_spaces() {
  while (substr(F_TEXT, F_POS, 1) == " ") {
    F_POS++
  }
}

# The character the reader stands on, spaces stepped over. Refuses the end
# of the line, since every caller expects more of the collection.
function flow_peek(__c) {
  flow_skip_spaces()
  __c = substr(F_TEXT, F_POS, 1)
  if (__c == "") {
    yaml_refuse("a flow collection that runs over lines")
  }
  return __c
}

# Reads a quoted scalar and returns the text it holds.
function flow_quoted(__end, __quoted) {
  __end = yaml_quote_end(F_TEXT, F_POS)
  if (__end == 0) {
    yaml_refuse("a quoted scalar that runs over lines")
  }
  __quoted = substr(F_TEXT, F_POS, __end - F_POS)
  F_POS = __end
  return yaml_unquote(__quoted)
}

# Reads a plain scalar up to the first character of stops, and returns its
# text with the spaces at its ends off.
function flow_plain(stops, __start) {
  __start = F_POS
  while (F_POS <= length(F_TEXT) && index(stops, substr(F_TEXT, F_POS, 1)) == 0) {
    F_POS++
  }
  return yaml_trim(substr(F_TEXT, __start, F_POS - __start))
}

# Reads one value: a collection, a quoted string, or a plain scalar.
function flow_value(__c) {
  __c = flow_peek()
  if (__c == "[") {
    return flow_sequence()
  }
  if (__c == "{") {
    return flow_mapping()
  }
  if (__c == "\"" || __c == "'") {
    return json_string_node(flow_quoted())
  }
  return yaml_plain_node(flow_plain(",]}"))
}

# Steps past the comma between two members, or stands still on the closer.
function flow_next_member(closer, __c) {
  __c = flow_peek()
  if (__c == ",") {
    F_POS++
  } else if (__c != closer) {
    yaml_refuse("a flow collection with no comma between two members")
  }
}

# Reads "[...]", standing on its "[".
function flow_sequence(__id) {
  __id = json_new("array")
  F_POS++
  while (flow_peek() != "]") {
    json_array_append(__id, flow_value())
    flow_next_member("]")
  }
  F_POS++
  return __id
}

# Reads one member's key.
function flow_key(__c) {
  __c = flow_peek()
  if (__c == "\"" || __c == "'") {
    return flow_quoted()
  }
  return flow_plain(":,}")
}

# Reads one member's value: what follows its colon, or null with no colon.
function flow_member_value() {
  if (flow_peek() != ":") {
    return json_null_node()
  }
  F_POS++
  if (index(",}", flow_peek()) > 0) {
    return json_null_node()
  }
  return flow_value()
}

# Reads "{...}", standing on its "{".
function flow_mapping(__id, __key) {
  __id = json_new("object")
  F_POS++
  while (flow_peek() != "}") {
    __key = flow_key()
    json_object_append(__id, __key, flow_member_value())
    flow_next_member("}")
  }
  F_POS++
  return __id
}

# The node of the flow collection that is the whole of text.
function yaml_flow_node(text, __id) {
  F_TEXT = text
  F_POS = 1
  __id = flow_value()
  flow_skip_spaces()
  if (F_POS <= length(F_TEXT)) {
    yaml_refuse("text after the end of a flow collection")
  }
  return __id
}
