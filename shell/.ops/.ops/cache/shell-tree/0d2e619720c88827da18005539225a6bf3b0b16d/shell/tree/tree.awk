# The lowering of a shell source to a tree of its definitions. Loaded after
# the scanner of shell-scan:
#
#   awk -v path=<the source's path> -f scan.awk -f tree.awk <source>
#
# The tree is one JSON document, the source node in the { role, name,
# payload } shape, with a node per root definition in file order:
#
#   { "role": "source", "name": "lib/greet.sh", "payload": [
#     { "role": "path", "payload": "lib/greet.sh" },
#     { "role": "doc", "name": "MODULE", "payload": "Greetings." },
#     { "role": "assignment", "name": "__greet__WORD", "payload": [
#       { "role": "line", "payload": 12 },
#       { "role": "doc", "name": "CONST", "payload": "The word every greeting opens with." } ] },
#     { "role": "function", "name": "greet", "payload": [
#       { "role": "line", "payload": 25 },
#       { "role": "doc", "name": "PUB_FUN", "payload": "Prints a greeting ..." } ] },
#     { "role": "function", "name": "undocumented", "payload": [
#       { "role": "line", "payload": 36 } ] } ] }
#
# The rules it reads by:
#
#   - A root definition is a function, `name() ...` or `function name ...`
#     at the start of a line, or an assignment, `name=...`, with `readonly`
#     or `export` before it, or the declaration `@enum name ...`. Every root
#     definition gets a node, documented or not.
#   - A doc is a doc block, the heredoc the no-op `:` consumes, or the
#     one-line form: a run of `#` lines whose first leads with an upper-case
#     word and a colon, `# WORD: text`. Its label is the heredoc's
#     terminator or that word, and its text is the body as written.
#   - A doc attaches to the definition on the line right after its closer.
#     A `#` line between them does not part them; a blank line does.
#   - The first doc block that a blank line follows, met before any
#     definition, is the source's own doc.
#   - The lowering knows no label and no naming convention: what a label
#     means, and what a name says, is for a reader of the tree to decide.

# The text of S as a JSON string: backslashes, quotes, newlines, tabs and
# carriage returns escaped. A backslash is doubled through `&`, the matched
# text, because awks disagree on how many backslashes a replacement that
# spells them out leaves behind.
function json_string(s) {
  gsub(/\\/, "&&", s)
  gsub(/"/, "\\\"", s)
  gsub(/\n/, "\\n", s)
  gsub(/\t/, "\\t", s)
  gsub(/\r/, "\\r", s)
  return "\"" s "\""
}

# A leaf node with ROLE and a string PAYLOAD.
function leaf(role, payload) {
  return "{\"role\":" json_string(role) ",\"payload\":" json_string(payload) "}"
}

# A leaf node with ROLE and a numeric PAYLOAD.
function number_leaf(role, payload) {
  return "{\"role\":" json_string(role) ",\"payload\":" payload "}"
}

# A named leaf: ROLE, NAME and a string PAYLOAD. A doc is one, its name the
# label.
function named_leaf(role, name, payload) {
  return "{\"role\":" json_string(role) ",\"name\":" json_string(name) ",\"payload\":" json_string(payload) "}"
}

# A composite node with ROLE, NAME and the comma-joined ITEMS as its payload.
function node(role, name, items) {
  return "{\"role\":" json_string(role) ",\"name\":" json_string(name) ",\"payload\":[" items "]}"
}

# ITEMS with ITEM appended, comma-joined; an empty ITEM adds nothing.
function append(items, item) {
  if (item == "") {
    return items
  }
  return (items == "" ? item : items "," item)
}

# True when LINE has no non-whitespace content.
function is_blank(line) {
  return (line !~ /[^ \t]/)
}

# True when the root comment LINE opens the one-line doc form: an upper-case
# word, a colon, and the first line of the text.
function is_typed_comment(line) {
  return (line ~ /^# [A-Z][A-Z_]*: /)
}

# The label the typed comment LINE leads with.
function typed_label(line, __label) {
  __label = line
  sub(/^# /, "", __label)
  sub(/:.*$/, "", __label)
  return __label
}

# The text of the typed comment LINE after its label, or of a continuation
# LINE after its `# `.
function comment_text(line, __text) {
  __text = line
  sub(/^# [A-Z][A-Z_]*: /, "", __text)
  sub(/^#[ \t]?/, "", __text)
  return __text
}

# Opens a pending doc from the typed comment LINE, so the definition below
# takes it the way it would take a doc block.
function open_typed_doc(line) {
  pending = 1
  pending_label = typed_label(line)
  pending_doc = comment_text(line)
  pending_lines = 1
  typed_open = 1
}

# Adds the continuation LINE of a typed comment to the pending doc.
function continue_typed_doc(line) {
  collect_doc_line(comment_text(line))
}

# True when LINE defines a function at the root of the file: `name()` or
# `function name`, with or without the parentheses after the keyword.
function is_root_function(line) {
  return (line ~ /^[A-Za-z_@][A-Za-z0-9_@]*[ \t]*\(\)/ || line ~ /^function[ \t]+[A-Za-z_@][A-Za-z0-9_@]*([ \t]|\(|$)/)
}

# The name the root function definition LINE defines.
function function_name(line, __name) {
  __name = line
  sub(/^function[ \t]+/, "", __name)
  sub(/[ \t(].*$/, "", __name)
  return __name
}

# True when LINE assigns a name at the root of the file or declares an enum.
function is_root_assignment(line) {
  return (line ~ /^(readonly[ \t]+|export[ \t]+)?[A-Za-z_][A-Za-z0-9_]*=/ || line ~ /^@enum[ \t]+[A-Za-z_]/)
}

# The name the root assignment LINE binds.
function assigned_name(line, __name) {
  __name = line
  sub(/^(readonly|export|@enum)[ \t]+/, "", __name)
  sub(/[=[ \t].*$/, "", __name)
  return __name
}

# The doc node of the pending doc: its label as the name, its text as the
# payload.
function pending_doc_node() {
  return named_leaf("doc", pending_label, pending_doc)
}

# Adds the node for the definition on LINE at line number AT, with the
# pending doc when one is pending, and clears it.
function add_definition(line, at, __name, __role, __items) {
  if (is_root_function(line)) {
    __name = function_name(line)
    __role = "function"
  } else {
    __name = assigned_name(line)
    __role = "assignment"
  }
  __items = number_leaf("line", at)
  if (pending) {
    __items = append(__items, pending_doc_node())
  }
  members = append(members, node(__role, __name, __items))
  pending = 0
}

# Settles the pending doc against its follower LINE at line number AT: a
# definition takes it; a blank line met before any definition makes it the
# source's doc; anything else leaves it unattached. Returns 1 when a
# definition on LINE took it, so the caller does not add that definition
# again.
function settle_pending(line, at) {
  if (is_root_function(line) || is_root_assignment(line)) {
    add_definition(line, at)
    return 1
  }
  if (is_blank(line) && source_doc == "" && !seen_definition && !typed_open) {
    source_doc = pending_doc_node()
  }
  pending = 0
  return 0
}

# Records LINE as part of the pending doc's body.
function collect_doc_line(line) {
  pending_doc = (pending_doc == "" && pending_lines == 0) ? line : pending_doc "\n" line
  pending_lines++
}

# Reads one line inside a heredoc: a doc block's line is collected, and the
# closer ends the heredoc.
function read_heredoc_line(line) {
  if (closes_heredoc(line)) {
    in_heredoc = 0
    in_doc = 0
    return
  }
  if (in_doc) {
    collect_doc_line(line)
  }
}

# Reads one line of code: continues or opens the one-line doc form, settles
# the pending doc against it, adds the node of the root definition it makes,
# and opens the heredoc it starts.
function read_code_line(line, __taken) {
  if (typed_open && is_comment(line)) {
    continue_typed_doc(line)
    return
  }
  typed_open = 0
  if (!pending && is_typed_comment(line)) {
    open_typed_doc(line)
    return
  }
  __taken = 0
  if (pending && is_blank(line)) {
    settle_pending("", FNR)
  } else if (pending && !is_comment(line)) {
    __taken = settle_pending(line, FNR)
  }
  if (!__taken && (is_root_function(line) || is_root_assignment(line))) {
    add_definition(line, FNR)
  }
  if (is_root_function(line) || is_root_assignment(line)) {
    seen_definition = 1
  }
  if (opens_heredoc(line)) {
    open_heredoc(line)
  }
}

# Opens the heredoc LINE starts, and the pending doc when it is a doc block.
function open_heredoc(line) {
  in_heredoc = 1
  if (opens_doc_block(line)) {
    in_doc = 1
    pending = 1
    pending_label = term
    pending_doc = ""
    pending_lines = 0
  }
}

BEGIN {
  members = ""
  typed_open = 0
  source_doc = ""
  pending = 0
  seen_definition = 0
  in_heredoc = 0
  in_doc = 0
}

{
  if (in_heredoc) {
    read_heredoc_line($0)
  } else {
    read_code_line($0)
  }
}

END {
  if (pending) {
    settle_pending("", FNR + 1)
  }
  header = append(leaf("path", path), source_doc)
  print node("source", path, append(header, members))
}
