# The doc-spacing check. Loaded with the scanner runtime and the doc-block
# library:
#
#   awk -f scan.awk -f doc_block.awk -f doc_spacing.awk
#
# Finds, in the files given:
#
#   - a doc block opener with no blank line above it
#   - a typed comment (`# CONST:`, `# PUB_CONST:`, `# VAR:`, `# PUB_VAR:`)
#     with no blank line above it
#
# The rules it reads by:
#
#   - A doc sits below a blank line, so the eye finds where the entry above
#     it ends. The first line of the file needs none, nor does the first
#     line of a block, right below the `{` that opens it, and a `#` line
#     above the doc, a directive or a check's allow marker, counts as the gap.
#   - A heredoc body is never read; its closer is a line like any other, so
#     a doc opened right below one is a finding.
#   - `# doc-spacing-check: allow` within three lines above a doc exempts it.
#
# Output: "<name>:<lineno>: <message>", <lineno> being FNR, awk's line number
# within the current file. Vars: -v fname=<display name> (default FILENAME).

# True when LINE is the one-line doc form (ADR 000040).
function is_typed(line) {
  return (line ~ /^# (CONST|PUB_CONST|VAR|PUB_VAR): /)
}

# True when LINE carries this check's own allow marker.
function is_allow_marker(line) {
  return (line ~ /doc-spacing-check:[ \t]*allow/)
}

# True when an allow marker sits within the three lines above the doc.
function doc_allowed() {
  return (allow_at >= FNR - 3 && allow_at < FNR)
}

# True when LINE ends on the `{` that opens a block, so the line below it is
# the block's first.
function opens_block(line) {
  return (line ~ /\{[ \t]*$/)
}

# Judges the doc that opens on this line against the line above it, PREV:
# blank, a comment, a block's opener, or nothing at all when the doc opens
# the file.
function judge_doc() {
  if (FNR == 1 || is_blank(prev) || is_comment(prev) || opens_block(prev) || doc_allowed()) {
    return
  }
  note(FNR, "a doc with no blank line above it; a blank line parts it from the line before")
}

# Reads one line inside a heredoc: the closer ends it.
function read_heredoc_line(line) {
  if (closes_heredoc(line)) {
    in_heredoc = 0
  }
}

# Reads one line of code: a doc it opens is judged, and the heredoc it
# starts is skipped.
function read_code_line(line) {
  if (is_allow_marker(line)) {
    allow_at = FNR
  }
  if (opens_doc_block(line) || is_typed(line)) {
    judge_doc()
  }
  if (opens_heredoc(line)) {
    in_heredoc = 1
  }
}

# Resets to the state a fresh file starts in.
function begin_file() {
  in_heredoc = 0
  prev = ""
  allow_at = -10
}

FNR == 1 {
  begin_file()
}

{
  if (in_heredoc) {
    read_heredoc_line($0)
  } else {
    read_code_line($0)
  }
  prev = $0
}
