# Flags a file that carries a file doc as well as a usage text. Defining a usage
# is what makes a file an entrypoint -- nothing else has help to print -- so the
# content settles whether the rule applies and no path is consulted. For an
# entrypoint the usage IS the file doc -- the same subject, addressed to the one
# reader who asked for it -- so a second copy above the code has no audience of
# its own and can only drift. Loaded with the scanner runtime and the doc-block
# library:
#   awk -f scan.awk -f doc_block.awk -f duplicate_file_doc.awk
#
# A file defines a usage when it has a usage() function anywhere or assigns
# USAGE before its first function definition. Such a file must carry no floating
# doc block before that same first definition -- floating meaning it documents no
# function, because what follows it does not define one, and no constant or
# variable, because it opens on none of their labels. The first definition is
# where a file stops introducing itself, so the preamble ends there.
#
# The verdict needs the whole file, because a usage may be defined as a function
# far below the code it describes, so the finding comes at the last line.
#
# Emits "<name>:<lineno>: <message>" anchored to the doc block's opener.
# Vars: -v fname=<display name> (default FILENAME).

# The usage text, however it is spelled. Most entrypoints assign a USAGE string;
# one whose help has to be built at runtime defines a function instead, and that
# is a usage all the same -- reading only the assignment would call such a file
# undocumented and let the duplication through.
function defines_usage(line) {
  return (defines_usage_function(line) || assigns_file_usage(line))
}

# A usage defined as a function, wherever it sits. A function is routinely
# defined below the code that calls it, so where this one lands says nothing
# about whose usage it is.
function defines_usage_function(line) {
  return (is_func_def(line) && line ~ /[Uu]sage[ \t]*\(\)/)
}

# A USAGE assigned while the file is still introducing itself. Past the first
# function definition the name is a body's own string, built for whatever that
# code needs, and a file is not an entrypoint on the strength of it.
function assigns_file_usage(line) {
  return (functions_seen == 0 && line ~ /^USAGE=/)
}

# Reports the file just finished when it had both a file doc and a usage.
function report_file() {
  if (file_name == "" || file_doc == 0 || !has_usage) {
    return
  }
  printf "%s:%d: %s\n", file_name, file_doc,
    "top-of-file doc block duplicates the usage; delete the doc block"
}

# Settles the doc block that just closed, given the first non-blank line after
# it (empty at end of file). A block sitting on a function documents it.
function settle_block(follower) {
  awaiting_kind = 0
  if (is_func_def(follower)) {
    return
  }
  if (file_doc == 0) {
    file_doc = pending_at
  }
}

# Resets to the state a fresh file starts in.
function begin_file() {
  file_name = display_name()
  file_doc = 0
  has_usage = 0
  functions_seen = 0
  awaiting_kind = 0
  in_heredoc = 0
  in_doc = 0
}

FNR == 1 {
  report_file()
  begin_file()
}

{
  if (in_heredoc) {
    if (closes_heredoc($0)) {
      in_heredoc = 0
      if (in_doc) {
        in_doc = 0
        awaiting_kind = 1
      }
    }
    next
  }

  if (awaiting_kind && !is_blank($0)) {
    settle_block($0)
  }

  if (defines_usage($0)) {
    has_usage = 1
  }

  if (is_func_def($0)) {
    functions_seen++
  }

  if (opens_heredoc($0)) {
    in_heredoc = 1
    if (opens_doc_block($0) && functions_seen == 0 && !is_assignment_label(term)) {
      in_doc = 1
      pending_at = FNR
    }
  }
}

END {
  if (awaiting_kind) {
    settle_block("")
  }
  report_file()
}
