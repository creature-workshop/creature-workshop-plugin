# Reads awk source one character at a time and says what each character is:
# code, part of a string or regex, or part of a `#` comment. The detectors that
# read awk load it so they agree on where code stops: two spellings of "inside
# a regex" would let one detector see a keyword where the other sees a literal,
# and nothing in either's findings would show the disagreement.
#
#   awk_lex_char("x")  ->  "code"
#   awk_lex_char("\"") ->  "literal", and so is every character up to the
#                          closing quote, the quote included
#   awk_lex_char("#")  ->  "comment", and so is every character up to the
#                          newline, which is code again
#
# `/` opens a regex after an operator, a delimiter or a newline, and divides
# after an identifier, a number, a closer or a literal. When that guess is
# wrong the characters that follow are read as a literal, so a detector misses
# a finding rather than inventing one.
#
# A detector feeds every character of a file in order, a "\n" at the end of
# each line included, and calls awk_lex_reset at the top of each file.
#
# Load it before the detector: `awk -f scan.awk -f awk_lex.awk -f <detector>`.

function awk_lex_reset() {
  awk_lex_state = "code"
  awk_lex_escaped = 0
  awk_lex_regex_ok = 1
}

function awk_lex_char(c) {
  if (awk_lex_state == "comment") {
    return awk_lex_comment_char(c)
  }
  if (awk_lex_state == "code") {
    return awk_lex_code_char(c)
  }
  return awk_lex_literal_char(c)
}

# A comment runs to the newline, and the newline is code.
function awk_lex_comment_char(c) {
  if (c != "\n") {
    return "comment"
  }
  awk_lex_state = "code"
  awk_lex_regex_ok = 1
  return "code"
}

# A string or regex runs to its unescaped closer, and what follows a literal
# is an operator, so a `/` there divides.
function awk_lex_literal_char(c) {
  if (awk_lex_escaped) {
    awk_lex_escaped = 0
  } else if (c == "\\") {
    awk_lex_escaped = 1
  } else if (c == awk_lex_closer()) {
    awk_lex_state = "code"
    awk_lex_regex_ok = 0
  }
  return "literal"
}

function awk_lex_closer() {
  return (awk_lex_state == "string" ? "\"" : "/")
}

function awk_lex_code_char(c) {
  if (c == "#") {
    awk_lex_state = "comment"
    return "comment"
  }
  if (c == "\"") {
    awk_lex_open("string")
    return "literal"
  }
  if (c == "/" && awk_lex_regex_ok) {
    awk_lex_open("regex")
    return "literal"
  }
  awk_lex_note_code(c)
  return "code"
}

function awk_lex_open(state) {
  awk_lex_state = state
  awk_lex_escaped = 0
}

# Records whether a `/` after the code character C would open a regex. A space
# leaves the answer as it stood.
function awk_lex_note_code(c) {
  if (c == " " || c == "\t") {
    return
  }
  awk_lex_regex_ok = (c == "\n" || index("{}(,;~!&|=<>?:+-*%^/", c) > 0)
}
