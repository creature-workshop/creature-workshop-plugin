# ops.awk -- what every op program leans on: its document, its path, its
# values, all already checked.

# The document the op's input rule accumulated, parsed -- or the process
# dies naming the parse error.
function json_doc() {
  return json_must(json_parse_doc(json_buf()))
}

# json_doc, required to be an array -- the jq verbs the array ops mirror
# all error on anything else, so the process dies speaking as <op>.
function json_doc_array(op, __root) {
  __root = json_doc()
  if (J_TYPE[__root] != "array") {
    json_must(json_fail(op ": expected an array, got " J_TYPE[__root]))
  }
  return __root
}

# The node at the path an op received via $SP_PATH, or -1 for absent. Dies
# on a path the backend does not speak.
function json_doc_path(root, __n) {
  __n = json_path_parse(ENVIRON["SP_PATH"])
  if (__n < 0) {
    json_must(json_fail("unsupported path: " ENVIRON["SP_PATH"]))
  }
  return json_get(root, __n)
}

# A JSON value an op received whole in the $<name> environment variable,
# parsed -- or the process dies naming the parse error.
function json_env_doc(name) {
  return json_must(json_parse_doc(ENVIRON[name]))
}

# The i-th child's JSON, or jq's null when there is no i-th child -- how
# the array-end verbs (@first, @last, @pop, @shift) answer for an empty
# array.
function json_element_or_null(id, i) {
  if (i >= 1 && i <= J_N[id]) {
    return json_serialize(J_CHILD[id, i])
  }
  return "null"
}

# Fills set[] with the serialized JSON of every element of array node id.
# The membership sets @intersect and @difference test against both come
# from here, so the two ops cannot disagree on what "the same element"
# means.
function json_element_set(id, set, __i) {
  for (__i = 1; __i <= J_N[id]; __i++) {
    set[json_serialize(J_CHILD[id, __i])] = 1
  }
}

# The i-th value an op received: SP_VAL_<i>, parsed as JSON when
# SP_ISJSON_<i> says it is one and wrapped as a string otherwise.
function json_env_value(i) {
  if (ENVIRON["SP_ISJSON_" i] == "1") {
    J_POS = 1
    return json_must(json_parse(ENVIRON["SP_VAL_" i]))
  }
  return json_string_node(ENVIRON["SP_VAL_" i])
}

# A value as the node it parses to when it is one whole JSON text, or a
# string node holding it otherwise -- the reading @push gives its arguments.
function json_value_or_string(s, __id) {
  __id = json_parse_doc(s)
  if (__id < 0) {
    return json_string_node(s)
  }
  return __id
}
