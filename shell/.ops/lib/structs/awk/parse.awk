# parse.awk -- JSON text to nodes: a recursive-descent parser over J_POS,
# the cursor into the string being parsed.

# One JSON value starting at J_POS; returns its node id (or -1) and leaves
# J_POS just past it.
function json_parse(s, __c) {
  json_ws(s)
  if (J_POS > length(s)) {
    return json_fail("unexpected end of input")
  }
  __c = substr(s, J_POS, 1)
  if (__c == "{") {
    return json_parse_object(s)
  }
  if (__c == "[") {
    return json_parse_array(s)
  }
  if (__c == "\"") {
    return json_parse_string(s)
  }
  if (__c == "t" || __c == "f") {
    return json_parse_literal(s, __c == "t" ? "true" : "false", "boolean")
  }
  if (__c == "n") {
    return json_parse_literal(s, "null", "null")
  }
  return json_parse_number(s)
}

# A whole document: one value with only whitespace after it.
function json_parse_doc(s, __id) {
  J_POS = 1
  J_ERR = ""
  __id = json_parse(s)
  if (__id < 0) {
    return __id
  }
  json_ws(s)
  if (J_POS <= length(s)) {
    return json_fail("trailing content after value")
  }
  return __id
}

function json_ws(s) {
  while (J_POS <= length(s) && index(" \t\n\r", substr(s, J_POS, 1)) > 0) {
    J_POS++
  }
}

function json_parse_object(s, __id) {
  __id = json_new("object")
  J_POS++
  json_ws(s)
  if (substr(s, J_POS, 1) == "}") {
    J_POS++
    return __id
  }
  while (1) {
    if (json_parse_member(s, __id) < 0) {
      return -1
    }
    json_ws(s)
    if (substr(s, J_POS, 1) == ",") {
      J_POS++
      continue
    }
    if (substr(s, J_POS, 1) == "}") {
      J_POS++
      return __id
    }
    return json_fail("expected ',' or '}' at " J_POS)
  }
}

# One `"key": value` member, appended onto the object.
function json_parse_member(s, obj, __key, __child) {
  json_ws(s)
  if (substr(s, J_POS, 1) != "\"") {
    return json_fail("expected object key at " J_POS)
  }
  __key = json_parse_string(s)
  if (__key < 0) {
    return __key
  }
  json_ws(s)
  if (substr(s, J_POS, 1) != ":") {
    return json_fail("expected ':' at " J_POS)
  }
  J_POS++
  __child = json_parse(s)
  if (__child < 0) {
    return __child
  }
  json_object_append(obj, J_STR[__key], __child)
  return __child
}

function json_parse_array(s, __id, __child) {
  __id = json_new("array")
  J_POS++
  json_ws(s)
  if (substr(s, J_POS, 1) == "]") {
    J_POS++
    return __id
  }
  while (1) {
    __child = json_parse(s)
    if (__child < 0) {
      return __child
    }
    json_array_append(__id, __child)
    json_ws(s)
    if (substr(s, J_POS, 1) == ",") {
      J_POS++
      continue
    }
    if (substr(s, J_POS, 1) == "]") {
      J_POS++
      return __id
    }
    return json_fail("expected ',' or ']' at " J_POS)
  }
}

function json_parse_string(s, __id, __out, __c, __piece) {
  __id = json_new("string")
  J_POS++
  __out = ""
  while (1) {
    if (J_POS > length(s)) {
      return json_fail("unterminated string")
    }
    __c = substr(s, J_POS, 1)
    if (__c == "\"") {
      J_POS++
      J_STR[__id] = __out
      return __id
    }
    if (__c == "\\") {
      __piece = json_decode_escape(s)
      if (J_ERR != "") {
        return -1
      }
      __out = __out __piece
      continue
    }
    __out = __out __c
    J_POS++
  }
}

# One backslash escape, decoded: J_POS sits on the backslash coming in and
# just past the escape going out. Returns the decoded text, or "" with J_ERR
# set on a form the grammar has no name for.
function json_decode_escape(s, __esc, __code, __hex) {
  __esc = substr(s, J_POS + 1, 1)
  if (index("ntrbf", __esc) > 0) {
    J_POS += 2
    return json_named_escape(__esc)
  }
  if (__esc == "\"" || __esc == "\\" || __esc == "/") {
    J_POS += 2
    return __esc
  }
  if (__esc == "u") {
    __hex = substr(s, J_POS + 2, 4)
    __code = json_hex4(__hex)
    if (__code < 0) {
      json_fail("bad \\u escape at " J_POS)
      return ""
    }
    J_POS += 6
    if (__code < 128) {
      return sprintf("%c", __code)
    }
    return "\\u" __hex
  }
  json_fail("bad escape '\\" __esc "' at " J_POS)
  return ""
}

# The character a single-letter escape names.
function json_named_escape(letter) {
  if (letter == "n") {
    return "\n"
  }
  if (letter == "t") {
    return "\t"
  }
  if (letter == "r") {
    return "\r"
  }
  if (letter == "b") {
    return "\b"
  }
  return "\f"
}

function json_hex4(h, __i, __c, __v, __n) {
  if (length(h) < 4) {
    return -1
  }
  __v = 0
  for (__i = 1; __i <= 4; __i++) {
    __c = tolower(substr(h, __i, 1))
    __n = index("0123456789abcdef", __c)
    if (__n == 0) {
      return -1
    }
    __v = __v * 16 + (__n - 1)
  }
  return __v
}

function json_parse_literal(s, word, type, __id) {
  if (substr(s, J_POS, length(word)) != word) {
    return json_fail("bad literal at " J_POS)
  }
  __id = json_new(type)
  J_RAW[__id] = word
  J_POS += length(word)
  return __id
}

function json_parse_number(s, __id, __start, __c) {
  __start = J_POS
  __c = substr(s, J_POS, 1)
  if (__c == "-") {
    J_POS++
  }
  if (substr(s, J_POS, 1) !~ /[0-9]/) {
    return json_fail("bad value at " __start)
  }
  while (J_POS <= length(s) && substr(s, J_POS, 1) ~ /[0-9eE+.\-]/) {
    J_POS++
  }
  __id = json_new("number")
  J_RAW[__id] = substr(s, __start, J_POS - __start)
  return __id
}
