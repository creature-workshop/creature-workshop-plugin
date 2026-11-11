# lines.awk -- what one line of an OPX document is, shared by every awk
# program that reads OPX so no two of them split a line differently.
#
# An OPX document is a tree, one node per line. A composite node is
# "<id> <depth>.<role>" and its children are the lines at depth+1 that follow
# it; a leaf is "<id> <depth>.<role>:<type>.<value>" and has none. A string
# value is double-quoted with \" \\ \n \t \r escaped; every other type's
# value is bare.
#
# A role is written bare when it is a word of [a-z][a-z0-9-]*, and quoted
# and escaped as a string value is when it is any other text, so a role can
# hold a space, a dot, a colon or nothing at all and the line still splits
# one way.
#
#   aaaac 2.read:string."lib/a.sh"
#   opx_id -> aaaac   opx_depth -> 2   opx_role -> read
#   opx_type -> string   opx_value -> lib/a.sh
#
#   aaaad 2."recorded_at":int.3
#   opx_role -> recorded_at   opx_role_is_quoted -> 1

# The node's id: everything before the first space.
function opx_id(line) {
  return substr(line, 1, index(line, " ") - 1)
}

# The line past its id: "<depth>.<role>" and, on a leaf, ":<type>.<value>".
function opx_body(line) {
  return substr(line, index(line, " ") + 1)
}

# The node's depth in the tree, the root at 0.
function opx_depth(line, __body) {
  __body = opx_body(line)
  return substr(__body, 1, index(__body, ".") - 1) + 0
}

# The line past its depth: "<role>" and, on a leaf, ":<type>.<value>".
function opx_node(line, __body) {
  __body = opx_body(line)
  return substr(__body, index(__body, ".") + 1)
}

# How many characters of node a quoted role takes, its two quotes counted:
# up to the first quote no backslash escapes.
function opx_quoted_role_length(node, __i, __c) {
  for (__i = 2; __i <= length(node); __i++) {
    __c = substr(node, __i, 1)
    if (__c == "\\") {
      __i++
    } else if (__c == "\"") {
      return __i
    }
  }
  return length(node)
}

# How many characters of node a bare role takes: up to the colon that opens
# a leaf's type, or all of a composite.
function opx_bare_role_length(node) {
  if (index(node, ":") == 0) {
    return length(node)
  }
  return index(node, ":") - 1
}

# The node's role as the line writes it, quotes and escapes included.
function opx_written_role(line, __node) {
  __node = opx_node(line)
  if (substr(__node, 1, 1) == "\"") {
    return substr(__node, 1, opx_quoted_role_length(__node))
  }
  return substr(__node, 1, opx_bare_role_length(__node))
}

# Whether the node's role is written quoted.
function opx_role_is_quoted(line) {
  return substr(opx_node(line), 1, 1) == "\""
}

# Whether the line is a leaf: whether anything follows its role.
function opx_is_leaf(line) {
  return length(opx_node(line)) > length(opx_written_role(line))
}

# The node's role: a quoted one unquoted and unescaped.
function opx_role(line, __written) {
  __written = opx_written_role(line)
  if (!opx_role_is_quoted(line)) {
    return __written
  }
  return opx_unescape(substr(__written, 2, length(__written) - 2))
}

# A leaf past its role: "<type>.<value>".
function opx_typed(line) {
  return substr(opx_node(line), length(opx_written_role(line)) + 2)
}

# A leaf's type, or nothing for a composite.
function opx_type(line, __typed) {
  if (!opx_is_leaf(line)) {
    return ""
  }
  __typed = opx_typed(line)
  return substr(__typed, 1, index(__typed, ".") - 1)
}

# A leaf's value as written: quoted and escaped for a string, bare otherwise.
function opx_raw_value(line, __typed) {
  __typed = opx_typed(line)
  return substr(__typed, index(__typed, ".") + 1)
}

# A leaf's value: a string unquoted and unescaped, any other type as written.
function opx_value(line, __raw) {
  __raw = opx_raw_value(line)
  if (opx_type(line) != "string") {
    return __raw
  }
  return opx_unescape(substr(__raw, 2, length(__raw) - 2))
}

# Whether the line is a well-formed node of either kind.
function opx_is_node(line) {
  return line ~ /^[a-zA-Z0-9_-]+ [0-9]+\.([a-z][a-z0-9-]*|"([^"\\]|\\.)*")(:[a-z][a-z0-9-]*\..*)?$/
}

# The character an escape's letter names, or the letter itself for \" and \\.
function opx_escaped_char(letter) {
  if (letter == "n") {
    return "\n"
  }
  if (letter == "t") {
    return "\t"
  }
  if (letter == "r") {
    return "\r"
  }
  return letter
}

# The text an escaped string value holds.
function opx_unescape(s, __out, __i, __c) {
  __out = ""
  for (__i = 1; __i <= length(s); __i++) {
    __c = substr(s, __i, 1)
    if (__c == "\\") {
      __i++
      __c = opx_escaped_char(substr(s, __i, 1))
    }
    __out = __out __c
  }
  return __out
}
