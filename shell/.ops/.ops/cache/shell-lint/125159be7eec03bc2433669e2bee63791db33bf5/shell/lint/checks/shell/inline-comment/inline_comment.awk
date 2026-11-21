# The inline-comment check (ADR 000040). Loaded with the scanner runtime and
# the doc-block library:
#
#   awk -v root=<repository root> -f scan.awk -f doc_block.awk -f inline_comment.awk
#
# Finds, in the files given:
#
#   - a `#` comment inside a function body
#   - a `#` comment at the root of the file above anything but a root
#     constant or variable, a function included
#   - a `#` comment above a root constant or variable that does not lead
#     with the label the name earns: `# CONST:`, `# PUB_CONST:`, `# VAR:`
#     or `# PUB_VAR:`
#   - a typed comment that runs past one line
#
# The rules it reads by:
#
#   - A line addressed to a tool is never a finding: the shebang, a
#     shellcheck directive, `# shim: <reason>`, a check's allow marker.
#   - A typed comment is the one-line form of the heredoc the
#     assignment-label check judges, and fills the same doc leaf. Its
#     label follows the same name rule: CONST for an upper-case last
#     segment, VAR otherwise, PUB_ in a library file for a name without
#     the leading `__`. It is one line: text that runs on is the heredoc's.
#   - What a body comment would explain goes in the function's doc, or the
#     function splits. A function's doc is a heredoc, whatever its length.
#   - `# inline-comment-check: allow` on the line, or within three lines
#     above a run, exempts that run.
#
# Output: "<name>:<lineno>: <message>", <lineno> being FNR, awk's line number
# within the current file. Vars: -v root=<dir> keys the files under the
# repository root; -v fname=<display name> (default FILENAME).

# The file's key: its path under the repository root, or from its last lib/ or
# interpreter/ component when it sits elsewhere. A path with neither keys to
# nothing.
function file_key(path) {
  if (root != "" && index(path, root "/") == 1) {
    return repo_key(path)
  }
  return library_key(path)
}

# True when KEY is a library file: under a library root (library_root.awk),
# and not a template for an entrypoint.
function is_library(key) {
  return (under_library_root(key) && key !~ /\.template\.sh$/)
}

# True when the comment LINE is addressed to a tool: the shebang, a shellcheck
# directive, a shim's reason, or a check's allow marker.
function is_directive(line) {
  if (line ~ /^#!/) {
    return 1
  }
  if (line ~ /^[ \t]*#[ \t]*shellcheck[ \t]/) {
    return 1
  }
  if (line ~ /^[ \t]*# shim: /) {
    return 1
  }
  return (line ~ /^[ \t]*# [a-z-]+(-check|-lint):[ \t]*allow/)
}

# True when LINE carries this check's own allow marker.
function is_allow_marker(line) {
  return (line ~ /inline-comment-check:[ \t]*allow/)
}

# True when the comment LINE leads with one of the four labels.
function is_typed(line) {
  return (line ~ /^# (CONST|PUB_CONST|VAR|PUB_VAR): /)
}

# The label the typed comment LINE leads with.
function typed_label(line, __label) {
  __label = line
  sub(/^# /, "", __label)
  sub(/:.*$/, "", __label)
  return __label
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

# The label the comment above NAME leads with: CONST or VAR by the name,
# PUB_ in a library file when the name has no leading `__`.
function expected_label(name, __kind) {
  __kind = is_constant_name(name) ? "CONST" : "VAR"
  if (!library || name ~ /^__/) {
    return __kind
  }
  return "PUB_" __kind
}

# True when a function-definition opener or a brace at column zero moves the
# scanner between the root and a body. A root function's body runs to the
# `}` at column zero that closes it.
function enters_body(line) {
  return (is_func_def(line) && line ~ /\{[ \t]*$/ && line !~ /\}[ \t]*$/)
}

# True when LINE is the brace at column zero closing a root function.
function leaves_body(line) {
  return (line ~ /^\}/)
}

# True when an allow marker sits on the run's first line or within the three
# lines above it.
function run_allowed() {
  return (allow_at >= run_start - 3 && allow_at <= run_start)
}

# Judges the root comment run that just ended, given its follower LINE: a
# typed run above an assignment is right when its label is the one the name
# earns and it is one line; any other run is a finding.
function settle_root_run(line, __name, __want) {
  if (run_allowed()) {
    return
  }
  if (!is_root_assignment(line)) {
    if (is_func_def(line)) {
      note(run_start, "a # comment above a function; a function's doc is a heredoc, whatever its length")
    } else {
      note(run_start, "a # comment addressed to a reader at the root of the file, above no constant or variable")
    }
    return
  }
  __name = assigned_name(line)
  __want = expected_label(__name)
  if (run_label == "") {
    note(run_start, "the comment above " __name " leads with no label; open it with # " __want ": ")
    return
  }
  if (run_label != __want) {
    note(run_start, "the comment above " __name " leads with " run_label "; the name earns " __want)
    return
  }
  if (run_len > 1) {
    note(run_start, "the comment above " __name " runs to " run_len " lines; the one-line form is one line, and longer text is a " __want " heredoc")
  }
}

# Judges a comment LINE inside a function body: a finding unless a tool
# reads it or an allow marker covers it.
function judge_body_comment(line) {
  if (is_directive(line) || is_allow_marker(line)) {
    return
  }
  if (allow_at >= FNR - 3 && allow_at <= FNR) {
    return
  }
  note(FNR, "a # comment inside a function body; say it in the function's doc, or split the function")
}

# Adds the root comment LINE to the pending run, opening one on its first
# line and reading the label off it.
function collect_root_comment(line) {
  if (run_len == 0) {
    run_start = FNR
    run_label = is_typed(line) ? typed_label(line) : ""
  }
  run_len++
}

# Resets to the state a fresh file starts in.
function begin_file() {
  library = is_library(file_key(FILENAME))
  in_body = 0
  run_len = 0
  allow_at = -10
  in_heredoc = 0
}

# Reads one line inside a heredoc: the closer ends it.
function read_heredoc_line(line) {
  if (closes_heredoc(line)) {
    in_heredoc = 0
  }
}

# Reads one line inside a function body: the brace at column zero ends the
# body, a comment is judged, and a heredoc the line opens is skipped.
function read_body_line(line) {
  if (is_allow_marker(line)) {
    allow_at = FNR
  }
  if (leaves_body(line)) {
    in_body = 0
  } else if (is_comment(line)) {
    judge_body_comment(line)
  }
  if (opens_heredoc(line)) {
    in_heredoc = 1
  }
}

# Reads one line at the root of the file: a reader-facing comment joins the
# pending run, and any other line settles the run against itself, a blank
# line settling it against nothing.
function read_root_line(line) {
  if (is_allow_marker(line)) {
    allow_at = FNR
  }
  if (is_comment(line)) {
    if (!is_directive(line) && !is_allow_marker(line)) {
      collect_root_comment(line)
    }
    return
  }
  if (run_len > 0) {
    settle_root_run(is_blank(line) ? "" : line)
    run_len = 0
  }
  if (is_blank(line)) {
    return
  }
  if (enters_body(line)) {
    in_body = 1
  }
  if (opens_heredoc(line)) {
    in_heredoc = 1
  }
}

FNR == 1 {
  begin_file()
}

{
  if (in_heredoc) {
    read_heredoc_line($0)
  } else if (in_body) {
    read_body_line($0)
  } else {
    read_root_line($0)
  }
}

END {
  if (run_len > 0) {
    settle_root_run("")
  }
}
