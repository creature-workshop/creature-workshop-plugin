# Conservative house-style scanner for awk. Flags unbraced if/else/for/while
# bodies, function-parameter locals that use a wide gap or an unprefixed
# name after a local, and a function defined below a pattern-action rule,
# since the rules close the file below every function (the entry expression
# last, as code-shape reads an awk program). Pattern-action rules are not
# control-flow. Assignments to fence/container globals are not parameters and
# are not flagged.
#
# Strings, regexes and `#` comments are skipped: the lexer the awk detectors
# share says which characters those are, and when its guess about a `/` is
# wrong the scanner swallows code (misses a finding) rather than flagging a
# literal. Unclosed quotes, unbraced `do`, and `do`/`while` pairings that are
# not `do { ... } while` are not followed.
#
# Load the emitter and the lexer first:
# `awk -f scan.awk -f awk_lex.awk -f awk_style_scan.awk`.

function is_space(c) {
  return (c == " " || c == "\t" || c == "\n")
}

function is_ident_char(c) {
  return (c ~ /[A-Za-z0-9_]/)
}

function is_dunder(name) {
  return (substr(name, 1, 2) == "__")
}

function is_wide_gap(gap, had_newline) {
  if (had_newline) {
    return 0
  }
  return (gap >= 2)
}

function reset_file_state() {
  awk_lex_reset()
  ident = ""
  ident_line = 0
  mode = "code"
  paren_depth = 0
  brace_depth = 0
  pending_kind = ""
  pending_line = 0
  after_do = 0
  do_block_depth = 0
  param_text = ""
  fn_line = 0
  first_rule_line = 0
  lane_reported = 0
}

# Notes a function defined below a pattern-action rule, once per file, at the
# function's line. A top-level line is a rule when it opens neither a function
# nor a closing brace; only the first rule's line is kept, so the finding says
# which rule the function fell below.
function note_lane(line, lineno) {
  if (brace_depth != 0) {
    return
  }
  if (line ~ /^function[[:space:]]/) {
    if (first_rule_line && !lane_reported) {
      note(lineno, "function below the rule at line " first_rule_line "; the pattern-action rules close the file, below every function")
      lane_reported = 1
    }
    return
  }
  if (first_rule_line == 0 && line ~ /^[^[:space:]#}]/) {
    first_rule_line = lineno
  }
}

function abandon_pending() {
  mode = "code"
  pending_kind = ""
}

function start_function() {
  mode = "want_fn_name"
  fn_line = ident_line
}

function start_cond(kind) {
  pending_kind = kind
  pending_line = ident_line
  mode = "want_paren"
}

function start_if() {
  start_cond("if")
}

function start_for() {
  start_cond("for")
}

function start_while() {
  if (after_do) {
    after_do = 0
    pending_kind = "do-while"
    pending_line = ident_line
    mode = "want_paren"
    return
  }
  start_cond("while")
}

function start_else() {
  pending_kind = "else"
  pending_line = ident_line
  mode = "else_look"
}

function start_do() {
  mode = "do_look"
}

function finish_cond() {
  if (pending_kind == "do-while") {
    mode = "code"
    pending_kind = ""
    return
  }
  mode = "await_body"
}

function handle_open_paren() {
  if (mode == "want_paren") {
    mode = "cond"
    paren_depth = 1
    return
  }
  if (mode == "want_fn_paren") {
    mode = "params"
    paren_depth = 1
    param_text = ""
    return
  }
  if (mode == "cond") {
    paren_depth++
    return
  }
}

function handle_close_paren() {
  if (mode == "cond") {
    paren_depth--
    if (paren_depth == 0) {
      finish_cond()
    }
    return
  }
}

function handle_open_brace() {
  brace_depth++
  if (mode == "do_look") {
    do_block_depth = brace_depth
    mode = "code"
    return
  }
  if (mode == "await_body" || mode == "else_look") {
    mode = "code"
    return
  }
}

function handle_close_brace() {
  brace_depth--
  if (do_block_depth != 0 && brace_depth < do_block_depth) {
    after_do = 1
    do_block_depth = 0
  }
}

function maybe_flag_unbraced(c) {
  if (mode == "await_body") {
    if (c == "{") {
      return
    }
    note(pending_line, "unbraced " pending_kind " body")
    mode = "code"
    return
  }
  if (mode == "else_look") {
    if (c == "{") {
      return
    }
    if (is_ident_char(c)) {
      return
    }
    note(pending_line, "unbraced else body")
    mode = "code"
    return
  }
  if (mode == "do_look") {
    if (c != "{") {
      mode = "code"
    }
    return
  }
}

function param_is_local(name, gap, had_newline, seen_local) {
  if (is_dunder(name)) {
    return 1
  }
  if (is_wide_gap(gap, had_newline)) {
    return 1
  }
  if (seen_local) {
    return 1
  }
  return 0
}

function report_param(name, gap, had_newline, seen_local, start_line) {
  if (is_wide_gap(gap, had_newline)) {
    note(start_line, "wide-gap before parameter '" name "'; locals are __-prefixed with a single space")
    return
  }
  if (seen_local && !is_dunder(name)) {
    note(start_line, "local parameter '" name "' must be prefixed with __")
    return
  }
}

function check_params(text, start_line, __i, __n, __c, __name, __gap, __seen_local, __after_sep, __had_newline) {
  __seen_local = 0
  __after_sep = 1
  __gap = 0
  __had_newline = 0
  __name = ""
  __n = length(text)
  for (__i = 1; __i <= __n; __i++) {
    __c = substr(text, __i, 1)
    if (__after_sep) {
      if (is_space(__c)) {
        if (__c == "\n") {
          __had_newline = 1
        }
        __gap++
        continue
      }
      __after_sep = 0
    }
    if (is_ident_char(__c)) {
      __name = __name __c
      continue
    }
    if (__name != "") {
      report_param(__name, __gap, __had_newline, __seen_local, start_line)
      if (param_is_local(__name, __gap, __had_newline, __seen_local)) {
        __seen_local = 1
      }
      __name = ""
    }
    if (__c == ",") {
      __after_sep = 1
      __gap = 0
      __had_newline = 0
    }
  }
  if (__name != "") {
    report_param(__name, __gap, __had_newline, __seen_local, start_line)
  }
}

function scan_params_char(c) {
  if (c == "(") {
    paren_depth++
    param_text = param_text c
    return
  }
  if (c == ")") {
    paren_depth--
    if (paren_depth == 0) {
      check_params(param_text, fn_line)
      mode = "code"
      param_text = ""
      return
    }
    param_text = param_text c
    return
  }
  param_text = param_text c
}

function handle_else_ident(name) {
  if (name == "if") {
    mode = "code"
    start_if()
    return
  }
  note(pending_line, "unbraced else body")
  mode = "code"
  dispatch_keyword(name)
}

function dispatch_keyword(name) {
  if (name == "function") {
    start_function()
    return
  }
  if (name == "if") {
    start_if()
    return
  }
  if (name == "for") {
    start_for()
    return
  }
  if (name == "while") {
    start_while()
    return
  }
  if (name == "else") {
    start_else()
    return
  }
  if (name == "do") {
    start_do()
    return
  }
}

function flush_ident(__name) {
  if (ident == "") {
    return
  }
  __name = ident
  ident = ""
  if (mode == "want_fn_name") {
    mode = "want_fn_paren"
    return
  }
  if (mode == "cond" || mode == "params") {
    return
  }
  if (mode == "else_look") {
    handle_else_ident(__name)
    return
  }
  dispatch_keyword(__name)
}

function handle_punct(c) {
  if (c == "(") {
    handle_open_paren()
    return
  }
  if (c == ")") {
    handle_close_paren()
    return
  }
  if (c == "{") {
    handle_open_brace()
    return
  }
  if (c == "}") {
    handle_close_brace()
    return
  }
  if (mode == "want_paren" || mode == "want_fn_paren" || mode == "want_fn_name") {
    abandon_pending()
  }
}

# Reads one character of code, CLASS being what the lexer made of it: a `#`
# or a space ends the word being read, and a quote or a regex's slash ends it
# too, after the unbraced-body check has seen the character.
function scan_code_char(c, class, line) {
  if (class == "comment" || is_space(c)) {
    flush_ident()
    return
  }
  maybe_flag_unbraced(c)
  if (class == "literal") {
    flush_ident()
    return
  }
  if (is_ident_char(c)) {
    if (ident == "") {
      ident_line = line
    }
    ident = ident c
    return
  }
  flush_ident()
  handle_punct(c)
}

# Hands the newline that ends a comment to whichever reader the comment
# interrupted.
function end_comment(c) {
  if (mode == "params") {
    scan_params_char(c)
  } else {
    flush_ident()
  }
}

# A parameter list is read as text, outside the lexer, except for a comment
# inside it, which the lexer skips. Elsewhere the lexer says what the character
# is, and only code, or the newline that ends a comment, reaches the scanner.
function scan_char(c, line, __in_code, __class) {
  __in_code = (awk_lex_state == "code")
  if (mode == "params" && __in_code && c != "#") {
    scan_params_char(c)
    return
  }
  __class = awk_lex_char(c)
  if (__in_code) {
    scan_code_char(c, __class, line)
    return
  }
  if (__class == "code") {
    end_comment(c)
  }
}

function scan_line(line, lineno, __i, __n, __c) {
  __n = length(line)
  for (__i = 1; __i <= __n; __i++) {
    __c = substr(line, __i, 1)
    scan_char(__c, lineno)
  }
  scan_char("\n", lineno)
}

BEGIN {
  reset_file_state()
}

FNR == 1 {
  reset_file_state()
}

{
  note_lane($0, FNR)
  scan_line($0, FNR)
}
