# The usage-label check. Loaded with the scanner runtime and the doc-block
# library:
#
#   awk -f scan.awk -f doc_block.awk -f usage_label.awk
#
# Finds, in the files given:
#
#   - a heredoc assigned to USAGE that does not open on HELP
#   - a heredoc opened on HELP that is not assigned to USAGE
#
# HELP is the label of an entrypoint's usage text, and carrying one is what
# marks a file as an entrypoint (ADR 000039). A usage heredoc is one opened
# on the line that assigns USAGE; every other heredoc is data.
#
# Output: "<name>:<lineno>: <message>", <lineno> being FNR, awk's line number
# within the current file. Vars: -v fname=<display name> (default FILENAME).

# True when LINE assigns the file's USAGE.
function assigns_usage(line) {
  return (line ~ /^USAGE=/)
}

# Judges the heredoc opened on LINE, whose terminator opens_heredoc left in
# `term`: a usage opens on HELP, and nothing else does.
function judge_opener(line) {
  if (assigns_usage(line)) {
    if (term != "HELP") {
      note(FNR, "usage heredoc opens on " term "; an entrypoint's usage opens on HELP")
    }
    return
  }
  if (term == "HELP") {
    note(FNR, "HELP names an entrypoint's usage; this heredoc is not assigned to USAGE")
  }
}

# Reads one line inside a heredoc: the closer ends it.
function read_heredoc_line(line) {
  if (closes_heredoc(line)) {
    in_heredoc = 0
  }
}

# Reads one line of code: a heredoc it opens is judged and then skipped.
function read_code_line(line) {
  if (opens_heredoc(line)) {
    in_heredoc = 1
    judge_opener(line)
  }
}

FNR == 1 {
  in_heredoc = 0
}

{
  if (in_heredoc) {
    read_heredoc_line($0)
  } else {
    read_code_line($0)
  }
}
