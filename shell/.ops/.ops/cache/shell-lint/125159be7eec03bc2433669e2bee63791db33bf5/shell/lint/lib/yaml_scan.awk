# Block-structure model for YAML, shared by the lint scanners that police
# structure rather than text. Loaded as a function library alongside a detector:
# `awk -f scan.awk -f yaml_scan.awk -f <detector>.awk`.
#
# Every line is classified as one of: a document marker, a mapping key, a
# scalar, or literal content belonging to the node above it. Content is any
# line indented deeper than the node that opened it, which is the one rule that
# covers a block scalar, a multi-line plain or quoted scalar, and a shell
# heredoc written inside a script entry alike -- none of their lines are YAML,
# so none of them can be mistaken for a key.
#
# A key's position is the chain of nodes enclosing it, sequence dashes
# included, so a key two levels down is never confused with a key one level
# down that happens to share its indentation.
#
# Flow collections (`{a: 1}`) are values, not structure: their interior is
# reported as the key's value text for a detector to read as it sees fit.
#
# The detector drives the state: call yaml_reset() on FNR == 1, then
# yaml_advance($0) once per record, and read the results from yaml_doc,
# yaml_kind, yaml_key, yaml_value, yaml_key_depth, and yaml_key_parent.

# Clears the model for a new file.
function yaml_reset() {
  yaml_doc = 1
  yaml_started = 0
  yaml_depth = 0
  yaml_skip = 0
  yaml_skip_indent = 0
  yaml_kind = ""
  yaml_key = ""
  yaml_value = ""
  yaml_key_depth = 0
  yaml_key_parent = ""
  yaml_key_parent_is_key = 0
}

# The width of LINE's leading whitespace.
function yaml_indent_of(line) {
  match(line, /^[ \t]*/)
  return RLENGTH
}

function yaml_is_blank(line) {
  return (line ~ /^[ \t]*$/)
}

function yaml_is_comment(line) {
  return (line ~ /^[ \t]*#/)
}

function yaml_is_doc_start(line) {
  return (line ~ /^---([ \t]|$)/)
}

function yaml_is_doc_end(line) {
  return (line ~ /^\.\.\.([ \t]|$)/)
}

# Strips leading and trailing whitespace from TEXT.
function yaml_trim(text, __out) {
  __out = text
  sub(/^[ \t]+/, "", __out)
  sub(/[ \t]+$/, "", __out)
  return __out
}

# TEXT trimmed, with one layer of surrounding quotes removed, so a quoted key
# compares equal to the same key written bare.
function yaml_unquote(text, __out) {
  __out = yaml_trim(text)
  if (__out ~ /^".*"$/ || __out ~ /^'.*'$/) {
    __out = substr(__out, 2, length(__out) - 2)
  }
  return __out
}

# True when REST -- a line with its indentation and any sequence dashes peeled
# off -- opens a mapping key. A plain key runs to the first colon that ends the
# line or is followed by a space, so a value carrying colons of its own (an
# `if:` rule, a URL, a quoted shell fragment) does not read as a second key.
function yaml_opens_key(rest) {
  return (rest ~ /^[^:]*:([ \t]|$)/)
}

function yaml_key_text(rest, __pos) {
  __pos = index(rest, ":")
  return substr(rest, 1, __pos - 1)
}

function yaml_value_text(rest, __pos) {
  __pos = index(rest, ":")
  return substr(rest, __pos + 1)
}

# The value a key carries. A key trailed by nothing but a comment carries no
# value and still opens a block below it, so the comment does not count -- read
# as a value it would make the key a leaf and hide everything under it.
function yaml_scalar_value(rest, __value) {
  __value = yaml_trim(yaml_value_text(rest))
  if (substr(__value, 1, 1) == "#") {
    return ""
  }
  return __value
}

# Enters the next document. The first marker in a file opens document 1 rather
# than closing it, so a leading `---` does not shift every document by one.
function yaml_start_document() {
  if (yaml_started) {
    yaml_doc++
  }
  yaml_started = 1
  yaml_depth = 0
  yaml_skip = 0
}

function yaml_end_document() {
  yaml_depth = 0
  yaml_skip = 0
}

# Drops the enclosing nodes that INDENT has closed: a node at the same
# indentation or deeper is a sibling or a child, not a parent.
function yaml_pop_to(indent) {
  while (yaml_depth > 0 && yaml_frame_indent[yaml_depth] >= indent) {
    yaml_depth--
  }
}

function yaml_push(indent, key, is_seq) {
  yaml_depth++
  yaml_frame_indent[yaml_depth] = indent
  yaml_frame_key[yaml_depth] = key
  yaml_frame_seq[yaml_depth] = is_seq
}

# Records the node enclosing the key now being read. A sequence dash encloses
# without naming anything, so it leaves the parent name empty -- which is how a
# key inside a sequence stays distinguishable from a key in a mapping at the
# same depth.
function yaml_note_parent() {
  yaml_key_depth = yaml_depth
  yaml_key_parent = ""
  yaml_key_parent_is_key = 0
  if (yaml_depth == 0 || yaml_frame_seq[yaml_depth]) {
    return
  }
  yaml_key_parent = yaml_frame_key[yaml_depth]
  yaml_key_parent_is_key = 1
}

# Marks the lines below this one as its literal content: everything indented
# deeper than INDENT belongs to the node that starts there.
function yaml_open_content(indent) {
  yaml_skip_indent = indent
  yaml_skip = 1
}

# True while LINE is still literal content of the node above it. A blank line
# never closes content, and a line at or above the opening indentation always
# does.
function yaml_continues_content(line) {
  if (!yaml_skip) {
    return 0
  }
  if (yaml_is_blank(line)) {
    return 1
  }
  return (yaml_indent_of(line) > yaml_skip_indent)
}

# Peels the sequence dashes off REST, pushing a node for each so a key that
# arrives through a sequence entry is never read as a child of the mapping the
# sequence belongs to. Returns REST with the dashes removed.
function yaml_peel_dashes(line, rest, indent, __rest, __at) {
  __rest = rest
  __at = indent
  while (__rest ~ /^-([ \t]|$)/) {
    yaml_pop_to(__at)
    yaml_push(__at, "-", 1)
    sub(/^-[ \t]*/, "", __rest)
    __at = length(line) - length(__rest)
  }
  return __rest
}

# Reads one record into the model and returns its kind: "marker" for a document
# boundary, "key" for a mapping key, "scalar" for a value with no key, "node"
# for a bare sequence dash, "content" for a line inside a scalar above it, or
# "" for a blank or comment line.
function yaml_advance(line, __raw, __rest, __eff, __dashed) {
  yaml_kind = ""
  yaml_key = ""
  yaml_value = ""
  yaml_key_depth = 0
  yaml_key_parent = ""
  yaml_key_parent_is_key = 0

  if (yaml_continues_content(line)) {
    yaml_kind = "content"
    return yaml_kind
  }
  yaml_skip = 0

  if (yaml_is_blank(line)) {
    return yaml_kind
  }

  __raw = yaml_indent_of(line)
  if (yaml_is_doc_start(line)) {
    yaml_start_document()
    yaml_kind = "marker"
    return yaml_kind
  }
  if (yaml_is_doc_end(line)) {
    yaml_end_document()
    yaml_kind = "marker"
    return yaml_kind
  }

  if (yaml_is_comment(line)) {
    return yaml_kind
  }

  yaml_started = 1
  __rest = substr(line, __raw + 1)
  __dashed = (__rest ~ /^-([ \t]|$)/)
  __rest = yaml_peel_dashes(line, __rest, __raw)
  __eff = length(line) - length(__rest)

  # A dash with nothing after it opens a node whose children are real YAML on
  # the lines below, so it must not swallow them as content.
  if (__rest == "") {
    yaml_kind = "node"
    return yaml_kind
  }

  if (!yaml_opens_key(__rest)) {
    # A scalar at column zero with no dash is a directive or a stray line, not
    # a node -- treating it as one would silently swallow the rest of the file.
    if (__raw > 0 || __dashed) {
      yaml_open_content(__raw)
    }
    yaml_kind = "scalar"
    return yaml_kind
  }

  yaml_pop_to(__eff)
  yaml_note_parent()
  yaml_key = yaml_unquote(yaml_key_text(__rest))
  yaml_value = yaml_scalar_value(__rest)
  yaml_kind = "key"

  # A key with a value is a leaf, so anything deeper is that value continuing.
  # A key without one is a container, and what follows are its children.
  if (yaml_value == "") {
    yaml_push(__eff, yaml_key, 0)
  } else {
    yaml_open_content(__eff)
  }
  return yaml_kind
}

# True when the key just read sits one level inside a named key -- the depth a
# job's own keywords occupy, given a document whose top level is the jobs.
function yaml_key_is_child_of_root() {
  return (yaml_kind == "key" && yaml_key_depth == 1 && yaml_key_parent_is_key)
}

# True when the key just read is at the document's top level.
function yaml_key_is_root() {
  return (yaml_kind == "key" && yaml_key_depth == 0)
}

# True when VALUE is a flow collection declaring NAME as a mapping key --
# structure written as a value, where the model cannot see it.
function yaml_flow_declares(value, name) {
  if (substr(value, 1, 1) != "{") {
    return 0
  }
  return (value ~ ("[{,][ \t]*[\"']?" name "[\"']?[ \t]*:"))
}
