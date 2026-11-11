# nodes.awk -- the parsed document's node table, and the operations on it
# that know nothing about text.
#
# One id per node:
#
#   J_TYPE[id]      "object" | "array" | "string" | "number" | "boolean" | "null"
#   J_RAW[id]       the scalar's lexeme as it appeared (numbers print verbatim)
#   J_STR[id]       the decoded text of a string node
#   J_N[id]         child count of an object or array
#   J_KEY[id, i]    the i-th key of an object, decoded (insertion order kept)
#   J_CHILD[id, i]  the i-th child's id

function json_new(type, __id) {
  __id = ++J_NID
  J_TYPE[__id] = type
  J_N[__id] = 0
  return __id
}

# A fresh string node holding s.
function json_string_node(s, __id) {
  __id = json_new("string")
  J_STR[__id] = s
  return __id
}

# A fresh null node.
function json_null_node(__id) {
  __id = json_new("null")
  J_RAW[__id] = "null"
  return __id
}

# The child under key, or -1 when the object has none.
function json_object_get(id, key, __i) {
  for (__i = 1; __i <= J_N[id]; __i++) {
    if (J_KEY[id, __i] == key) {
      return J_CHILD[id, __i]
    }
  }
  return -1
}

# Sets key to value, replacing an existing entry or appending a new one.
function json_object_put(id, key, value, __i) {
  for (__i = 1; __i <= J_N[id]; __i++) {
    if (J_KEY[id, __i] == key) {
      J_CHILD[id, __i] = value
      return
    }
  }
  json_object_append(id, key, value)
}

# Appends a key/child pair without looking for an existing key -- the
# parser's fast path; json_object_put is the read-modify one.
function json_object_append(id, key, child) {
  J_N[id]++
  J_KEY[id, J_N[id]] = key
  J_CHILD[id, J_N[id]] = child
}

# Appends one element to an array.
function json_array_append(id, child) {
  J_N[id]++
  J_CHILD[id, J_N[id]] = child
}

# Grows an array with nulls until it holds at least n children.
function json_array_grow(id, n) {
  while (J_N[id] < n) {
    json_array_append(id, json_null_node())
  }
}

# An object's keys in sorted order, filled into keys[1..n] (insertion sort;
# POSIX awk has no builtin one). Returns n.
function json_sorted_keys(id, keys, __i, __j, __k) {
  for (__i = 1; __i <= J_N[id]; __i++) {
    __k = J_KEY[id, __i]
    for (__j = __i - 1; __j >= 1 && keys[__j] > __k; __j--) {
      keys[__j + 1] = keys[__j]
    }
    keys[__j + 1] = __k
  }
  return J_N[id]
}
