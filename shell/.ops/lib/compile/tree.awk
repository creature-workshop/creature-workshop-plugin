# The tree lowering: one library module in, its tree out (ADR 000039).
# Loaded with the scanner runtime and the doc-block library:
#
#   awk -v path=<the module's path under PROJ> -f scan.awk -f doc_block.awk -f tree.awk
#
# The tree is what help and the reference render, and neither reads the
# source. It is one JSON document, the module node in the IR's
# { role, name, payload } shape (ADR 000009):
#
#   { "role": "module", "name": "lib/git/api.sh", "payload": [
#     { "role": "path", "payload": "lib/git/api.sh" },
#     { "role": "reach", "payload": "module" },
#     { "role": "doc", "payload": "Git as the library reads it." },
#     { "role": "function", "name": "git__tracked_files", "payload": [
#       { "role": "line", "payload": 217 },
#       { "role": "doc", "payload": "Print the files under a directory ..." },
#       { "role": "contract", "payload": [
#         { "role": "visibility", "payload": "public" },
#         { "role": "args", "payload": [
#           { "role": "arg", "name": "$1", "payload": [
#             { "role": "meaning", "payload": "The directory to list" } ] } ] } ] } ] } ] }
#
# The rules it reads by:
#
#   - A doc block attaches to the line right after its closer. A `#` line
#     between them does not part them; a blank line does. The first block
#     followed by a blank line, met before any definition, is the file's
#     doc; its label, MODULE or FRAGMENT, is the module's reach.
#   - Every root function gets a node. One with no doc still does, its
#     visibility read off its name, so the reference can say it is
#     undocumented.
#   - A root constant or variable gets a node when it carries a doc: a
#     heredoc, or the one-line form, a run of `#` lines whose first leads
#     with `# CONST:`, `# PUB_CONST:`, `# VAR:` or `# PUB_VAR:` (ADR
#     000040).
#   - The contract's first entry is visibility, from the PUB_ label. Its
#     second is args, one arg per parameter line under the doc's `args:`
#     heading (`$1`, `$@`, `<name>` or a flag, then its meaning; a deeper
#     indented line continues the meaning), up to a blank line or the next
#     heading doc_block.awk knows. A doc with no args section adds none.

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

# True when the root comment LINE opens the one-line doc form: a label, a
# colon, and the first line of the text.
function is_typed_comment(line) {
  return (line ~ /^# (CONST|PUB_CONST|VAR|PUB_VAR): /)
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
  sub(/^# (CONST|PUB_CONST|VAR|PUB_VAR): /, "", __text)
  sub(/^#[ \t]?/, "", __text)
  return __text
}

# Opens a pending doc from the typed comment LINE, so the assignment below
# takes it the way it would take a heredoc.
function open_typed_doc(line) {
  pending = 1
  pending_label = typed_label(line)
  pending_doc = comment_text(line)
  pending_lines = 1
  doc_lines[1] = pending_doc
  typed_open = 1
}

# Adds the continuation LINE of a typed comment to the pending doc.
function continue_typed_doc(line) {
  collect_doc_line(comment_text(line))
}

# True when LINE defines a function at the root of the file.
function is_root_function(line) {
  return (line ~ /^(function[ \t]+)?[A-Za-z_@][A-Za-z0-9_@]*[ \t]*\(\)/)
}

# The name the root function definition LINE defines.
function function_name(line, __name) {
  __name = line
  sub(/^function[ \t]+/, "", __name)
  sub(/[ \t]*\(.*$/, "", __name)
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

# True when NAME is a constant's: its last `__` segment is upper case.
function is_constant_name(name, __last) {
  __last = name
  while (index(__last, "__") > 0) {
    __last = substr(__last, index(__last, "__") + 2)
  }
  return (__last ~ /^[A-Z][A-Z0-9_]*$/)
}

# The visibility a doc LABEL states, or the empty string when the label
# states none.
function label_visibility(label) {
  if (label ~ /^PUB_/) {
    return "public"
  }
  if (label == "FUN" || label == "CONST" || label == "VAR") {
    return "private"
  }
  return ""
}

# The visibility NAME states on its own: private under ADR 000031's leading
# `__`, public otherwise.
function name_visibility(name) {
  return (name ~ /^__/ ? "private" : "public")
}

# The contract node carrying VISIBILITY and, when the doc has an args
# section, its ARGS node.
function contract(visibility, args) {
  return node_without_name("contract", append(leaf("visibility", visibility), args))
}

# True when LINE is the heading of a doc's args section.
function is_args_heading(line) {
  return (line ~ /^[ \t]*([Aa]rgs|[Aa]rguments):[ \t]*$/)
}

# True when LINE names a parameter: a positional or special parameter, an
# angle-bracketed name, or a flag, followed by its meaning.
function is_arg_line(line) {
  return (line ~ /^[ \t]*(\$[0-9@#*]+(\.\.)?|<[^>]+>|--?[A-Za-z][A-Za-z0-9_-]*)[ \t]+[^ \t]/)
}

# The parameter the arg LINE names.
function arg_name(line, __name) {
  __name = line
  sub(/^[ \t]*/, "", __name)
  sub(/[ \t].*$/, "", __name)
  return __name
}

# The meaning the arg LINE gives, after the parameter and the gap.
function arg_meaning(line, __meaning) {
  __meaning = line
  sub(/^[ \t]*[^ \t]+[ \t]+/, "", __meaning)
  return __meaning
}

# The args node parsed from the pending doc's lines, or the empty string when
# the doc has no args section: one arg per parameter line under the heading,
# a deeper-indented line continuing the meaning above it, up to a blank line
# or the next section heading.
function pending_args(__i, __in, __items, __name, __meaning, __width, __line) {
  __in = 0
  __items = ""
  __name = ""
  for (__i = 1; __i <= pending_lines; __i++) {
    __line = doc_lines[__i]
    if (!__in) {
      if (is_args_heading(__line)) {
        __in = 1
      }
      continue
    }
    if (is_blank(__line) || is_section_heading(__line)) {
      break
    }
    if (is_arg_line(__line)) {
      if (__name != "") {
        __items = append(__items, arg(__name, __meaning))
      }
      __name = arg_name(__line)
      __meaning = arg_meaning(__line)
      __width = indent_width(__line)
      continue
    }
    if (__name != "" && indent_width(__line) > __width) {
      __meaning = __meaning " " trimmed(__line)
    }
  }
  if (__name != "") {
    __items = append(__items, arg(__name, __meaning))
  }
  return (__items == "" ? "" : node_without_name("args", __items))
}

# The arg node for the parameter NAME with MEANING.
function arg(name, meaning) {
  return node("arg", name, leaf("meaning", meaning))
}

# LINE without its leading whitespace.
function trimmed(line) {
  sub(/^[ \t]*/, "", line)
  return line
}

# A composite node with ROLE and no name.
function node_without_name(role, items) {
  return "{\"role\":" json_string(role) ",\"payload\":[" items "]}"
}

# Adds the node for the definition on LINE at line number AT, with the
# pending doc when one is pending, and clears it.
function add_definition(line, at, __name, __role, __items, __visibility, __args) {
  if (is_root_function(line)) {
    __name = function_name(line)
    __role = "function"
  } else {
    __name = assigned_name(line)
    __role = is_constant_name(__name) ? "constant" : "variable"
  }
  __items = number_leaf("line", at)
  __visibility = ""
  __args = ""
  if (pending) {
    __items = append(__items, leaf("doc", pending_doc))
    __visibility = label_visibility(pending_label)
    __args = pending_args()
  }
  if (__visibility == "") {
    __visibility = name_visibility(__name)
  }
  __items = append(__items, contract(__visibility, __args))
  members = append(members, node(__role, __name, __items))
  pending = 0
}

# Settles the pending doc against its follower LINE at line number AT: a
# file label makes it the module's doc, a definition takes it, anything
# else leaves it unattached. Returns 1 when a definition on LINE took it,
# so the caller does not add that definition again.
function settle_pending(line, at) {
  if (pending_label == "MODULE" || pending_label == "FRAGMENT") {
    if (module_doc == "" && !seen_definition) {
      module_reach = tolower(pending_label)
      module_doc = pending_doc
    }
    pending = 0
    return 0
  }
  if (is_root_function(line) || is_root_assignment(line)) {
    add_definition(line, at)
    return 1
  }
  pending = 0
  return 0
}

# Records LINE as part of the pending doc's body, as text and as a line.
function collect_doc_line(line) {
  pending_doc = (pending_doc == "" && pending_lines == 0) ? line : pending_doc "\n" line
  pending_lines++
  doc_lines[pending_lines] = line
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
# the pending doc against it, adds the node of the root function it defines,
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
  if (!__taken && is_root_function(line)) {
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
  module_doc = ""
  module_reach = ""
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
  header = leaf("path", path)
  if (module_reach != "") {
    header = append(header, leaf("reach", module_reach))
    header = append(header, leaf("doc", module_doc))
  }
  print node("module", path, append(header, members))
}
