# Flags a doc block whose prose runs past the cap for its kind. Only prose
# counts: a doc that is long because it tabulates parameters or an environment
# is as long as the interface it describes, and shortening it would cost the
# reader information the code does not carry. Loaded with the scanner runtime
# and the doc-block library:
#   awk -f scan.awk -f doc_block.awk -f oversized_doc_block.awk
#
# A module header states what a whole file is for and gets the wider cap. It is
# recognized by what surrounds it: nothing above it defines a function, and what
# follows it is not one either. A block sitting directly on top of a function
# documents that function however early in the file it appears, so the verdict
# waits for the line after the block closes.
#
# Emits "<name>:<lineno>: <message>" anchored to the block's opener.
# Vars: -v func_cap and -v header_cap are the two prose-line limits;
# -v fname=<display name> (default FILENAME).

# Records the doc block opening on the current line.
function open_block() {
  open_at = FNR
  open_follows_function = (functions_seen > 0)
  body_lines = 0
}

# Holds the closed block's measurements until the line that says what kind of
# block it was.
function close_block() {
  pending_at = open_at
  pending_name = display_name()
  pending_prose = prose_line_count(body, body_lines)
  pending_follows_function = open_follows_function
  awaiting_kind = 1
}

# Settles the held block against the cap for its kind, given the first non-blank
# line after it (empty at end of file, where nothing follows).
function settle_block(follower, __is_header, __cap) {
  awaiting_kind = 0
  __is_header = (!pending_follows_function && !is_func_def(follower))
  __cap = (__is_header ? header_cap : func_cap)

  if (pending_prose <= __cap) {
    return
  }

  printf "%s:%d: %s doc block runs %d prose lines (cap %d); move detail into a labelled section or drop it\n", \
    pending_name, pending_at, (__is_header ? "module header" : "function doc"), pending_prose, __cap
}

FNR == 1 {
  if (awaiting_kind) {
    settle_block("")
  }
  in_heredoc = 0
  in_doc = 0
  functions_seen = 0
}

{
  if (in_heredoc) {
    if (closes_heredoc($0)) {
      in_heredoc = 0
      if (in_doc) {
        close_block()
        in_doc = 0
      }
    } else if (in_doc) {
      body_lines++
      body[body_lines] = $0
    }
    next
  }

  if (awaiting_kind && !is_blank($0)) {
    settle_block($0)
  }

  if (is_func_def($0)) {
    functions_seen++
  }

  if (opens_heredoc($0)) {
    in_heredoc = 1
    if (opens_doc_block($0)) {
      in_doc = 1
      open_block()
    }
  }
}

END {
  if (awaiting_kind) {
    settle_block("")
  }
}
