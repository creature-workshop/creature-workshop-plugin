# Flags an if whose then-body is @true or @false alone and whose else-body is
# the other constructor alone:
#
#   if [ "$x" = y ]; then
#     @true
#   else
#     @false
#   fi
#
# That is a predicate written by hand, and `@succeeds <condition>` (or
# `@fails`) is the one line that replaces it. The finding is reported once,
# at the `if` line. A guard that prints one constructor and returns is not
# this shape, and neither is an if whose condition is a list joined with &&
# or ||: @succeeds runs one command, so that if has no one-line rewrite.
# Loaded with the scanner runtime: `awk -f scan.awk -f boolean_branch.awk`.
#
# Heredoc bodies are skipped, so a doc block that shows the shape is never
# policed, and comments are stripped before a line is read. A line covered by
# a '# structs-lint: allow' marker (on it, or within the three lines above)
# is exempt; the marker is the one the structs checks share, since this
# check polices the same API.
#
# Between lines the detector keeps the statements it has seen, in order: each
# line is split at `;`, a `then` or `else` that opens a body on the same line
# is split from the body, and a line continued with a trailing backslash
# takes the next into itself. The shape is then the same five statements
# before `fi` however the lines are laid out, and the detector reads them
# back when a `fi` arrives.
#
# Emits "<name>:<lineno>: <message>" anchored to the if line.
# Vars: -v fname=<display name> (default FILENAME).

# LINE without leading and trailing whitespace.
function trimmed(line) {
  sub(/^[[:space:]]+/, "", line)
  sub(/[[:space:]]+$/, "", line)
  return line
}

# Forgets the previous file's statements.
function reset_statements() {
  count = 0
}

# Records STATEMENT, read from the source LINE, after the statements before
# it. A `then` or `else` followed by a body on the same line is recorded as
# two statements, and a statement continued with a trailing backslash takes
# the next one into itself.
function push_statement(statement, line, __body) {
  if (statement == "") {
    return
  }
  if (continues_last_statement()) {
    sub(/[[:space:]]*\\$/, "", statements[count])
    statements[count] = statements[count] " " statement
    return
  }
  if (statement ~ /^(then|else)[[:space:]]+/) {
    __body = statement
    sub(/^(then|else)[[:space:]]+/, "", __body)
    push_statement(substr(statement, 1, 4), line)
    push_statement(__body, line)
    return
  }
  count++
  statements[count] = statement
  statement_line[count] = FNR
}

# Splits LINE into its statements and records each.
function push_line(line, __n, __parts, __i) {
  __n = split(line, __parts, ";")
  for (__i = 1; __i <= __n; __i++) {
    push_statement(trimmed(__parts[__i]), line)
  }
}

# True when the statement recorded last ends in a backslash, so the next
# statement is its continuation.
function continues_last_statement() {
  return (count > 0 && statements[count] ~ /\\$/)
}

# The statement recorded last, empty when none has been.
function last_statement() {
  return (count > 0 ? statements[count] : "")
}

# True when STATEMENT joins commands with && or ||, so it is not the one
# command @succeeds runs.
function is_list(statement) {
  return (statement ~ /[[:space:]](&&|\|\|)[[:space:]]/)
}

# True when STATEMENT is one of the boolean constructors.
function is_constructor(statement) {
  return (statement == "@true" || statement == "@false")
}

# The line of the if that opens a hand-written predicate, when the five
# statements before the `fi` just recorded are an if, then, one constructor,
# else and the other constructor; 0 otherwise.
function hand_written_predicate_line(__if) {
  if (count < 6) {
    return 0
  }
  __if = count - 5
  if (statements[__if] !~ /^if[[:space:]]/ || statements[__if + 1] != "then") {
    return 0
  }
  if (is_list(statements[__if])) {
    return 0
  }
  if (!is_constructor(statements[__if + 2]) || statements[__if + 3] != "else") {
    return 0
  }
  if (!is_constructor(statements[__if + 4]) || statements[__if + 4] == statements[__if + 2]) {
    return 0
  }
  return statement_line[__if]
}

# Reports the predicate that the `fi` on the current line closes, unless an
# allow marker covers the if or the fi.
function report_closed_predicate(__line) {
  __line = hand_written_predicate_line()
  if (__line == 0) {
    return
  }
  if (__line <= allow_until || FNR <= allow_until) {
    return
  }
  note(__line, "predicate written as an if whose branches are @true and @false; write @succeeds <condition> (or @fails)")
}

# Reset per-file state so a single awk run can scan many files. allow_until is
# the last line number covered by the most recent allow marker.
FNR == 1 {
  in_heredoc = 0
  allow_until = 0
  reset_statements()
}

{
  if (in_heredoc) {
    if (closes_heredoc($0)) {
      in_heredoc = 0
    }
    next
  }

  if ($0 ~ /structs-lint:[ \t]*allow/) {
    allow_until = FNR + 3
  }

  if (opens_heredoc($0)) {
    in_heredoc = 1
  }

  stripped = $0
  sub(/#.*/, "", stripped)
  push_line(stripped)

  if (last_statement() == "fi") {
    report_closed_predicate()
  }
}
