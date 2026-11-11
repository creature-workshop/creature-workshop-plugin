# scalars.awk -- what a YAML scalar is: which value a plain one names, and
# the text a quoted one holds. Shared by the reader and the writer, so the
# writer quotes exactly the strings the reader would read as something else.
#
# A plain scalar is null ("", "~", "null"), a boolean ("true", "false"), or a
# number when it is written as JSON writes one; anything else is a string.
# "007", "+5" and "0x1F" stay strings, since no JSON number spells them, and
# so do "yes" and "on", which only the older YAML read as booleans.
#
#   yaml_plain_type("1.5")   ->  number     yaml_plain_type("1.5.0")  ->  string
#   yaml_plain_type("~")     ->  null       yaml_plain_type("yes")    ->  string

# The JSON type a plain scalar names.
function yaml_plain_type(text) {
  if (text ~ /^(|~|null|Null|NULL)$/) {
    return "null"
  }
  if (text ~ /^(true|True|TRUE|false|False|FALSE)$/) {
    return "boolean"
  }
  if (text ~ /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][-+]?[0-9]+)?$/) {
    return "number"
  }
  return "string"
}

# A fresh node holding a scalar's text as the type names it.
function yaml_typed_node(type, text, __id) {
  if (type == "string") {
    return json_string_node(text)
  }
  if (type == "null") {
    return json_null_node()
  }
  __id = json_new(type)
  J_RAW[__id] = (type == "boolean") ? tolower(text) : text
  return __id
}

# A fresh node holding the value a plain scalar names.
function yaml_plain_node(text) {
  return yaml_typed_node(yaml_plain_type(text), text)
}

# The character a double-quoted escape's letter names. An escape this reader
# has no name for is kept as written, which is how the node table carries a
# \uXXXX past ASCII.
function yaml_escaped_char(letter) {
  if (letter == "n") {
    return "\n"
  }
  if (letter == "t") {
    return "\t"
  }
  if (letter == "r") {
    return "\r"
  }
  if (letter == "\"" || letter == "\\" || letter == "/") {
    return letter
  }
  return "\\" letter
}

# The text between a pair of double quotes, its escapes read.
function yaml_unescape_double(inner, __out, __i, __c) {
  __out = ""
  for (__i = 1; __i <= length(inner); __i++) {
    __c = substr(inner, __i, 1)
    if (__c == "\\") {
      __i++
      __c = yaml_escaped_char(substr(inner, __i, 1))
    }
    __out = __out __c
  }
  return __out
}

# The text between a pair of single quotes, where '' is one quote.
function yaml_unescape_single(inner) {
  gsub(/''/, "'", inner)
  return inner
}

# The text a quoted scalar holds, quoted being the scalar with its quotes on.
function yaml_unquote(quoted, __inner) {
  __inner = substr(quoted, 2, length(quoted) - 2)
  if (substr(quoted, 1, 1) == "\"") {
    return yaml_unescape_double(__inner)
  }
  return yaml_unescape_single(__inner)
}

# Whether a string can be written plain and read back as the same string:
# words of safe characters with single spaces between, that no YAML reader,
# old or new, takes for a number, a boolean or a null.
function yaml_is_plain_safe(text) {
  if (text !~ /^[A-Za-z_\/][A-Za-z0-9_.\/@%+=-]*( [A-Za-z0-9_.\/@%+=-]+)*$/) {
    return 0
  }
  if (text ~ /^(y|Y|yes|Yes|YES|n|N|no|No|NO|on|On|ON|off|Off|OFF)$/) {
    return 0
  }
  return yaml_plain_type(text) == "string"
}

# Whether a string can be written as a literal block and read back as the
# same string: it runs over lines, opens on a line that holds something and
# does not start with a space, and has no carriage return and no line of
# spaces alone, which a block cannot tell from an empty one.
function yaml_is_block_safe(text) {
  if (index(text, "\n") == 0 || text ~ /\r/) {
    return 0
  }
  if (text ~ /^[ \n]/ || text ~ /(^|\n)[ \t]+(\n|$)/) {
    return 0
  }
  return 1
}
