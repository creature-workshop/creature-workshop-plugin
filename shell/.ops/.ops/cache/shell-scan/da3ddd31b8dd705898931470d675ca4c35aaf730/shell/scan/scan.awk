# The heredoc scanner: the runtime a detector loads first, and reads the
# source through.
#
#   awk -f scan.awk -f <detector>.awk <files...>
#
# awk has no include, so a detector is a second program loaded after this
# one, and the two share one namespace. This file defines functions only,
# and a detector drives them from its own rules. Together they are the hook
# contract every detector and the doc extractor read:
#
#   opens_heredoc(line)   1 when the line opens a heredoc; sets term and dashed
#   opens_doc_block(line) 1 when the heredoc the line opens is a doc block
#   closes_heredoc(line)  1 when the line closes the heredoc term names
#   is_comment(line)      1 when the line is a `#` comment and nothing else
#   is_func_def(line)     1 when the line opens a function definition
#   note(line, msg)       prints a finding as <name>:<line>: <msg>
#   display_name()        the name findings carry: -v fname, else FILENAME
#
# The detector keeps the heredoc state: it sets in_heredoc=1 after
# opens_heredoc returns 1, and clears it once closes_heredoc returns 1. A
# detector that resets its state at FNR == 1 reads every file in one run.
#
# Heredoc tracking is by terminator word only: it never counts parentheses,
# tracks nesting or reindents, so, unlike a structural formatter, it cannot
# be confused by $(...), an inline case, a continued line or a quoted program
# in a body. A body is where aligned prose, a literal `#` and embedded code
# are never policed, and every detector skips it by these hooks so no two
# detectors draw the boundary differently.
# The display name for findings: -v fname when set, else the current FILENAME.
function display_name() {
  return (fname == "" ? FILENAME : fname)
}

# Emits a finding as "<name>:<line>: <message>" anchored to <line>.
function note(line, msg) {
  printf "%s:%d: %s\n", display_name(), line, msg
}

# True when LINE is a `#` comment and nothing else. Shared so every detector
# draws the line between a comment and code in the same place.
function is_comment(line) {
  return (line ~ /^[ \t]*#/)
}

# A function-definition opener: `name() ...` or `function name ...`. The name
# class is permissive enough to cover the @-sigil structs verbs (@get(), ...).
# Shared so every detector draws the line between preamble and body in the same
# place -- two spellings would let one detector see a function where another
# sees none, and nothing in the output would show the disagreement.
function is_func_def(line, __name_then_parens, __function_keyword) {
  __name_then_parens = "^[ \t]*[A-Za-z_@][A-Za-z0-9_@]*[ \t]*\\(\\)"
  __function_keyword = "^[ \t]*function[ \t]+[A-Za-z_@]"
  return (line ~ __name_then_parens || line ~ __function_keyword)
}

# True when LINE closes the open heredoc. A plain heredoc closes on a line equal
# to the terminator word; the <<- form additionally allows leading tabs.
function closes_heredoc(line, __trimmed) {
  if (dashed) {
    __trimmed = line
    sub(/^\t+/, "", __trimmed)
    return (__trimmed == term)
  }
  return (line == term)
}

# Records the heredoc opened on LINE, if any, and returns 1. Recognizes
# `<< WORD`, `<<-WORD`, and the quoted `<<'WORD'` / `<<"WORD"` forms; here-
# strings (<<<) and arithmetic shifts (`<< 2`) are not heredocs and return 0.
function opens_heredoc(line, __rest) {
  if (line ~ /<<</) {
    return 0
  }
  if (line !~ /<<-?[ \t]*["']?[A-Za-z_]/) {
    return 0
  }

  dashed = (line ~ /<<-/)
  __rest = line
  sub(/^.*<<-?[ \t]*["']?/, "", __rest)
  match(__rest, /[A-Za-z_][A-Za-z0-9_]*/)
  term = substr(__rest, 1, RLENGTH)
  return 1
}

# True when LINE opens a doc block rather than a data heredoc: the no-op `:`
# is what consumes the heredoc, so nothing reads its body but a reader of
# the source, and its terminator is the label of what it documents. The
# heredoc state still comes from opens_heredoc; ask this beside it.
function opens_doc_block(line) {
  return (line ~ /^[ \t]*:[ \t]*<</)
}
