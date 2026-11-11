# Flags an awk program that exits with an answer while it still has input to
# read. A reader that exits early closes the pipe on a writer still writing;
# the writer dies on SIGPIPE, and under pipefail the pipeline fails with 141
# although the answer was right. Whether the writer had finished is scheduling,
# so the failure comes and goes. The remedy is to record the answer, skip the
# remaining lines, and exit from END.
#
#   { quoted = is_quoted($0); exit }        ->  finding
#   { quoted = is_quoted($0); decided = 1 } ->  clean, with `decided { next }` above
#
# Not findings:
#   - an exit inside END, where the input is already read, or inside BEGIN,
#     which runs before any of it is;
#   - an error exit, `exit` followed by a non-zero number: that pipeline fails
#     either way;
#   - an exit with `# early-exit-check: allow` within the three lines above it.
#
# Strings, regexes and `#` comments are blanked before a line is read, by the
# lexer the awk detectors share.
#
# Load the emitter and the lexer first:
# `awk -f scan.awk -f awk_lex.awk -f awk_early_exit.awk`.

function main(line, __code) {
  if (FNR == 1) {
    reset_file_state()
  }
  if (is_allow_marker(line)) {
    allow_at = FNR
  }

  __code = code_of(line)
  enter_item(__code)
  report_early_exit(__code)

  track_braces(__code)
}

function reset_file_state() {
  awk_lex_reset()
  depth = 0
  kind = ""
  allow_at = 0
}

function is_allow_marker(line) {
  return (line ~ /early-exit-check:[ \t]*allow/)
}

# Names the top-level item CODE opens, when CODE sits outside every brace.
function enter_item(code) {
  if (depth == 0 && code ~ /[^ \t]/) {
    kind = item_kind(code)
  }
}

# The kind of top-level item CODE opens: "begin", "end", "function" or "rule".
function item_kind(code) {
  if (code ~ /^BEGIN([^A-Za-z0-9_]|$)/) {
    return "begin"
  }
  if (code ~ /^END([^A-Za-z0-9_]|$)/) {
    return "end"
  }
  if (code ~ /^function[ \t]/) {
    return "function"
  }
  return "rule"
}

# Notes the exit CODE holds, unless it is one of the exits the header exempts.
function report_early_exit(code, __operand) {
  __operand = exit_operand(code)
  if (__operand == "-" || reads_no_more_input() || is_error_status(__operand) || exit_allowed()) {
    return
  }
  note(FNR, "exit with input left to read; record the answer, skip the remaining lines, and exit from END")
}

function reads_no_more_input() {
  return (kind == "begin" || kind == "end")
}

# True when OPERAND is a non-zero number, the spelling of an error exit.
function is_error_status(operand) {
  return (operand ~ /^[0-9]+$/ && operand + 0 != 0)
}

function exit_allowed() {
  return (allow_at != 0 && allow_at >= FNR - 3 && allow_at < FNR)
}

# What follows the first `exit` word in CODE, trimmed, or "-" when CODE holds
# no such word.
#
#   found = 1; exit !found  ->  "!found"
function exit_operand(code, __rest, __at) {
  __rest = code
  while ((__at = index(__rest, "exit")) > 0) {
    if (is_whole_word(__rest, __at, 4)) {
      return operand_after(substr(__rest, __at + 4))
    }
    __rest = substr(__rest, __at + 4)
  }
  return "-"
}

# True when the LENGTH characters of TEXT at AT have no identifier character on
# either side.
function is_whole_word(text, at, length_, __before, __after) {
  __before = (at == 1 ? "" : substr(text, at - 1, 1))
  __after = substr(text, at + length_, 1)
  return (!is_ident_char(__before) && !is_ident_char(__after))
}

function is_ident_char(c) {
  return (c ~ /[A-Za-z0-9_]/)
}

# The first word of REST, up to a space, a semicolon or a closing brace.
function operand_after(rest) {
  sub(/^[ \t]+/, "", rest)
  sub(/[ \t;}]+.*$/, "", rest)
  return rest
}

# Moves DEPTH by the braces CODE holds.
function track_braces(code, __opens, __closes, __copy) {
  __copy = code
  __opens = gsub(/\{/, "", __copy)
  __closes = gsub(/\}/, "", __copy)
  depth += __opens - __closes
  if (depth < 0) {
    depth = 0
  }
}

# LINE with every string, regex and comment turned to spaces, so that a word or
# a brace found in what remains is code. awk_lex.awk says which characters
# those are.
#
#   if (s == "exit") { n++ }  # exit here  ->  if (s ==       ) { n++ }
function code_of(line, __code, __i, __n, __c) {
  __n = length(line)
  for (__i = 1; __i <= __n; __i++) {
    __c = substr(line, __i, 1)
    __code = __code (awk_lex_char(__c) == "code" ? __c : " ")
  }
  awk_lex_char("\n")
  return __code
}

{ main($0) }
