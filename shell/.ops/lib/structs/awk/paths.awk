# paths.awk -- jq-style paths: parsing them into segments, and walking or
# growing a document along them.
#
# A parsed path lives in J_SEG[1..n]: object keys as themselves, array
# indices as "#N" so a numeric object key cannot be mistaken for one. P_POS
# is the cursor into the path text, distinct from the value parser's J_POS.

# Parses p into J_SEG; returns the segment count, or -1 on a form the
# backend does not speak. `.` alone is the empty path, and a dot directly
# before `[` belongs to the index segment that follows, so jq's canonical
# `.[0]` spelling reads the same as `.list[0]`.
function json_path_parse(p, __n, __c) {
  __n = 0
  P_POS = 1
  if (p == ".") {
    return 0
  }
  while (P_POS <= length(p)) {
    __c = substr(p, P_POS, 1)
    if (__c == ".") {
      if (substr(p, P_POS + 1, 1) == "[") {
        P_POS++
        continue
      }
      if (json_path_key(p, __n + 1) < 0) {
        return -1
      }
      __n++
      continue
    }
    if (__c == "[") {
      if (json_path_index(p, __n + 1) < 0) {
        return -1
      }
      __n++
      continue
    }
    return -1
  }
  return __n
}

# One `.key` or `."quoted key"` segment into J_SEG[at]; P_POS sits on the
# dot coming in and just past the segment going out.
function json_path_key(p, at, __end, __seg) {
  P_POS++
  if (substr(p, P_POS, 1) == "\"") {
    __end = index(substr(p, P_POS + 1), "\"")
    if (__end == 0) {
      return -1
    }
    J_SEG[at] = substr(p, P_POS + 1, __end - 1)
    P_POS += __end + 1
    return 0
  }
  __seg = ""
  while (P_POS <= length(p) && substr(p, P_POS, 1) ~ /[A-Za-z0-9_-]/) {
    __seg = __seg substr(p, P_POS, 1)
    P_POS++
  }
  if (__seg == "") {
    return -1
  }
  J_SEG[at] = __seg
  return 0
}

# One `[N]` segment into J_SEG[at], as "#N".
function json_path_index(p, at, __end, __seg) {
  __end = index(substr(p, P_POS), "]")
  if (__end == 0) {
    return -1
  }
  __seg = substr(p, P_POS + 1, __end - 2)
  if (__seg !~ /^[0-9]+$/) {
    return -1
  }
  J_SEG[at] = "#" __seg
  P_POS += __end
  return 0
}

# True (1) when a segment names an array index.
function json_seg_is_index(seg) {
  return substr(seg, 1, 1) == "#"
}

function json_seg_index(seg) {
  return substr(seg, 2) + 1
}

# The node at J_SEG[1..n] under root, or -1 when the path walks off the
# document (jq's null).
function json_get(root, n, __i, __id) {
  __id = root
  for (__i = 1; __i <= n; __i++) {
    __id = json_step(__id, J_SEG[__i])
    if (__id < 0) {
      return -1
    }
  }
  return __id
}

# One step of a walk: the child seg names under id, or -1.
function json_step(id, seg, __j) {
  if (json_seg_is_index(seg) && J_TYPE[id] == "array") {
    __j = json_seg_index(seg)
    if (__j > J_N[id]) {
      return -1
    }
    return J_CHILD[id, __j]
  }
  if (J_TYPE[id] != "object") {
    return -1
  }
  return json_object_get(id, seg)
}

# Sets J_SEG[1..n] under root to value's node, creating missing parents as
# objects the way jq's assignment does. Returns 0, or -1 when a step lands
# on a scalar that cannot carry children.
function json_set(root, n, value, __i, __id) {
  __id = root
  for (__i = 1; __i < n; __i++) {
    __id = json_step_into(__id, J_SEG[__i])
    if (__id < 0) {
      return -1
    }
  }
  return json_place(__id, J_SEG[n], value)
}

# One step of a grow-walk: the child seg names, created as an object when
# absent or scalar; -1 when id itself cannot carry children.
function json_step_into(id, seg, __j, __next) {
  if (json_seg_is_index(seg) && J_TYPE[id] == "array") {
    __j = json_seg_index(seg)
    json_array_grow(id, __j)
    return J_CHILD[id, __j]
  }
  if (J_TYPE[id] != "object") {
    return -1
  }
  __next = json_object_get(id, seg)
  if (__next < 0 || (J_TYPE[__next] != "object" && J_TYPE[__next] != "array")) {
    __next = json_new("object")
    json_object_put(id, seg, __next)
  }
  return __next
}

# Puts value at the final segment under id; -1 when id cannot carry it.
function json_place(id, seg, value, __j) {
  if (json_seg_is_index(seg) && J_TYPE[id] == "array") {
    __j = json_seg_index(seg)
    json_array_grow(id, __j)
    J_CHILD[id, __j] = value
    return 0
  }
  if (J_TYPE[id] != "object") {
    return -1
  }
  json_object_put(id, seg, value)
  return 0
}
