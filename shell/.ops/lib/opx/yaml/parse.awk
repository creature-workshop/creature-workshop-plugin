# parse.awk -- a YAML document read into the structs node table, the same
# table a JSON document is read into, so a value is one thing whichever it
# was written in. Loaded after the structs JSON runtime and lines.awk,
# scalars.awk, flow.awk and blocks.awk.
#
# It reads the YAML a config or a pipeline file is written in: block
# mappings and sequences, plain and quoted scalars, literal and folded
# blocks, one-line flow collections, comments. What it does not read it
# refuses, naming the line: anchors and aliases, tags, merge keys, complex
# keys, directives, a second document, and a scalar or flow collection that
# runs over lines.
#
#   jobs:                    ->  {"jobs":[{"name":"test","needs":[]}]}
#     - name: test
#       needs: []

# Whether text is an element of a block sequence.
function yaml_is_item(text) {
  return text == "-" || text ~ /^- /
}

# Refuses a value or key that opens with a construct this reader leaves out.
function yaml_refuse_unread(text) {
  if (text ~ /^&/) {
    yaml_refuse("an anchor")
  }
  if (text ~ /^\*/) {
    yaml_refuse("an alias")
  }
  if (text ~ /^!/) {
    yaml_refuse("a tag")
  }
}

# Splits a quoted key off text, which opens with its quote. Returns whether
# a colon follows the quoted scalar, which is what makes it a key.
function yaml_split_quoted_key(text, __end, __after) {
  __end = yaml_quote_end(text, 1)
  if (__end == 0) {
    yaml_refuse("a quoted scalar that runs over lines")
  }
  __after = substr(text, __end)
  if (__after !~ /^ *:( |$)/) {
    return 0
  }
  Y_KEY = yaml_unquote(substr(text, 1, __end - 1))
  sub(/^ *:/, "", __after)
  Y_REST = yaml_trim(__after)
  return 1
}

# Splits a plain key off text at its first ": ", or at a colon that ends it.
function yaml_split_plain_key(text, __at) {
  __at = index(text, ": ")
  if (__at == 0 && text ~ /:$/) {
    __at = length(text)
  }
  if (__at <= 1) {
    return 0
  }
  Y_KEY = yaml_rtrim(substr(text, 1, __at - 1))
  Y_REST = yaml_trim(substr(text, __at + 1))
  yaml_refuse_unread(Y_KEY)
  if (Y_KEY == "<<") {
    yaml_refuse("a merge key")
  }
  return 1
}

# Whether text is a mapping's "key: value". When it is, Y_KEY holds the key
# and Y_REST what follows its colon.
function yaml_split_key(text) {
  if (text ~ /^[\[{]/ || yaml_is_item(text)) {
    return 0
  }
  if (text ~ /^\? /) {
    yaml_refuse("a complex key")
  }
  if (text ~ /^["']/) {
    return yaml_split_quoted_key(text)
  }
  return yaml_split_plain_key(text)
}

# The node of a value written on the rest of one line.
function yaml_inline_node(text, __end) {
  yaml_refuse_unread(text)
  if (text ~ /^[\[{]/) {
    return yaml_flow_node(text)
  }
  if (text ~ /^["']/) {
    __end = yaml_quote_end(text, 1)
    if (__end != length(text) + 1) {
      yaml_refuse(__end == 0 ? "a quoted scalar that runs over lines" : "text after the end of a quoted scalar")
    }
    return json_string_node(yaml_unquote(text))
  }
  return yaml_plain_node(text)
}

# The node of the lines indented further than indent, or null when the next
# line is not.
function yaml_nested_node(indent) {
  yaml_skip_blank()
  if (Y_POS <= Y_N && Y_INDENT[Y_POS] > indent) {
    return yaml_node(Y_INDENT[Y_POS])
  }
  return json_null_node()
}

# The node under a key with nothing after its colon: a sequence at the key's
# own indentation, which YAML allows, or whatever is indented further.
function yaml_under_key(indent) {
  Y_POS++
  if (yaml_at(indent) && yaml_is_item(Y_TEXT[Y_POS])) {
    return yaml_sequence(indent)
  }
  return yaml_nested_node(indent)
}

# The node of the value the reader stands on, rest being what follows its
# key's colon or its item's dash, and indent where that key or dash sits.
function yaml_value(indent, rest, __id) {
  if (yaml_is_block_header(rest)) {
    return yaml_block_node(indent, rest)
  }
  __id = yaml_inline_node(rest)
  Y_POS++
  return __id
}

# Reads a block mapping whose keys sit at indent.
function yaml_mapping(indent, __id, __key, __rest) {
  __id = json_new("object")
  while (yaml_at(indent) && yaml_split_key(Y_TEXT[Y_POS])) {
    __key = Y_KEY
    __rest = Y_REST
    json_object_append(__id, __key, __rest == "" ? yaml_under_key(indent) : yaml_value(indent, __rest))
  }
  return __id
}

# Reads one element, standing on its dash. An element that opens a mapping
# or another sequence on the dash's own line is read as if what follows the
# dash began a line of its own, indented to where it sits.
function yaml_item(indent, __text, __rest, __inner) {
  __text = Y_TEXT[Y_POS]
  __rest = __text
  sub(/^- */, "", __rest)
  if (__rest == "") {
    Y_POS++
    return yaml_nested_node(indent)
  }
  if (!yaml_is_block_header(__rest) && (yaml_is_item(__rest) || yaml_split_key(__rest))) {
    __inner = indent + length(__text) - length(__rest)
    Y_INDENT[Y_POS] = __inner
    Y_TEXT[Y_POS] = __rest
    return yaml_node(__inner)
  }
  return yaml_value(indent, __rest)
}

# Reads a block sequence whose dashes sit at indent.
function yaml_sequence(indent, __id) {
  __id = json_new("array")
  while (yaml_at(indent) && yaml_is_item(Y_TEXT[Y_POS])) {
    json_array_append(__id, yaml_item(indent))
  }
  return __id
}

# Reads the node that begins on the line the reader stands on, at indent.
function yaml_node(indent, __text) {
  __text = Y_TEXT[Y_POS]
  if (yaml_is_item(__text)) {
    return yaml_sequence(indent)
  }
  if (yaml_split_key(__text)) {
    return yaml_mapping(indent)
  }
  return yaml_value(indent, __text)
}

# Steps over the "---" that may open the document.
function yaml_skip_document_start() {
  yaml_skip_blank()
  if (Y_POS <= Y_N && Y_TEXT[Y_POS] ~ /^%/) {
    yaml_refuse("a directive")
  }
  if (Y_POS <= Y_N && Y_TEXT[Y_POS] == "---") {
    Y_POS++
  }
}

# Refuses whatever is left once the document's one value has been read.
function yaml_refuse_leftover() {
  yaml_skip_blank()
  if (Y_POS <= Y_N && Y_TEXT[Y_POS] == "...") {
    Y_POS++
    yaml_skip_blank()
  }
  if (Y_POS > Y_N) {
    return
  }
  yaml_refuse(Y_TEXT[Y_POS] ~ /^---/ ? "a second document" : "out of place in the tree")
}

# The node of the whole document kept with yaml_keep_line, null when it
# holds nothing.
function yaml_doc(__id) {
  yaml_read_lines()
  yaml_skip_document_start()
  yaml_skip_blank()
  if (Y_POS > Y_N) {
    return json_null_node()
  }
  __id = yaml_node(Y_INDENT[Y_POS])
  yaml_refuse_leftover()
  return __id
}
