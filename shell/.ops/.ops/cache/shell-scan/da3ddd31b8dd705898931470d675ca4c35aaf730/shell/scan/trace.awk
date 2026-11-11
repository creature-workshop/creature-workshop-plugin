# The trace of a source through the scanner: what the hooks answer for each
# line, printed through note(). It is the detector the tests load to show
# the scanner's reading of a fixture, and the smallest example of the hook
# contract scan.awk states:
#
#   awk -v fname=<name> -f scan.awk -f trace.awk <files...>
#
# A line inside a heredoc traces as `body`, and its closer as `closes
# <term>`. A line of code traces as `comment`, `function` or `code`, and one
# that opens a heredoc adds `opens <<term` or `opens <<-term`, with `doc`
# before the form when the heredoc is a doc block. The state is reset at the
# first line of each file, so many files read in one run.

# The word for LINE outside a heredoc: comment, function or code.
function classify(line) {
  if (is_comment(line)) {
    return "comment"
  }
  if (is_func_def(line)) {
    return "function"
  }
  return "code"
}

# The trace of the opener LINE: whether it opens a doc block, then the form
# and the terminator opens_heredoc recorded.
function opener_trace(line) {
  return "opens " (opens_doc_block(line) ? "doc " : "") (dashed ? "<<-" : "<<") term
}

# Traces LINE inside a heredoc, and leaves the heredoc on its closer.
function trace_body_line(line) {
  if (closes_heredoc(line)) {
    in_heredoc = 0
    note(FNR, "closes " term)
    return
  }
  note(FNR, "body")
}

# Traces LINE outside a heredoc, and enters the heredoc it opens.
function trace_code_line(line, __word) {
  __word = classify(line)
  if (opens_heredoc(line)) {
    in_heredoc = 1
    __word = __word ", " opener_trace(line)
  }
  note(FNR, __word)
}

FNR == 1 { in_heredoc = 0 }

in_heredoc { trace_body_line($0); next }

{ trace_code_line($0) }
