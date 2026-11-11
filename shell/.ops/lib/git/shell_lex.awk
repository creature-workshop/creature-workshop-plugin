# Splits shell commands into words for the classifiers, reading them the way
# the shell itself would:
#
#   - text inside quotes joins one word and can never start a command
#   - ; & | ( ) begin a new sub-command (a "segment"), except inside quotes
#   - a `$( )`, `<( )`, `>( )`, or backtick substitution is a segment of its
#     own, so the command it embeds is judged; a `$( )` inside double quotes
#     still runs, so it is opened too (one level deep)
#   - a redirection -- `>log`, `2>&1`, `<in`, `&>out`, and the target word of
#     a bare `>` or `<` -- is no word of its command
#   - everything between a <<EOF and its closing EOF line is skipped whole
#
# So a classifier only judges real commands: `git push origin main` typed as
# a command matches, while the same text inside an echo argument, a quoted
# JSON payload, or a heredoc script is data and never will. Load this file
# first (awk -f shell_lex.awk -f <classifier>.awk); per record it fills
# words[1..nwords] with seg[1..nwords] segment ids and redirect[1..nwords]
# marks, and its skip rule runs for every classifier loaded after it.

# Fill words[1..nwords] and their segment ids seg[1..nwords] from one record.
function shell_lex(line, __i, __n) {
  reset_lex()
  __n = length(line)
  for (__i = 1; __i <= __n; __i++) {
    __i += lex_char(line, __i)
  }
  flush_word()
}

function reset_lex() {
  nwords = 0
  nsegs = 1
  seg_open = 0
  lex_quote = ""
  lex_tok = ""
  lex_resume_quote = ""
  lex_sub_depth = 0
  lex_target_pending = 0
}

# Consume the character at position i; returns how many extra characters were
# taken (an escape takes its follower).
function lex_char(line, i, __c) {
  __c = substr(line, i, 1)
  if (lex_quote != "") {
    return quoted_char(line, i, __c)
  }
  if (__c == "'" || __c == "\"") {
    lex_quote = __c
    return 0
  }
  if (__c == "\\") {
    lex_tok = lex_tok substr(line, i + 1, 1)
    return 1
  }
  if (__c == " " || __c == "\t") {
    flush_word()
    return 0
  }
  if (opens_substitution(line, i, __c)) {
    return 0
  }
  if (joins_redirection(line, i, __c)) {
    lex_tok = lex_tok __c
    return 0
  }
  if (__c == "`") {
    cut_segment()
    return 0
  }
  if (is_operator(__c)) {
    cut_segment()
    track_lifted_substitution(__c)
    return 0
  }
  lex_tok = lex_tok __c
  return 0
}

# True when c is the `$`, `<`, or `>` in front of a `(`: the opener of a
# substitution, dropped here so the `(` that follows cuts the embedded command
# into a segment of its own without leaving the opener as a word.
function opens_substitution(line, i, c) {
  return (c == "$" || c == "<" || c == ">") && substr(line, i + 1, 1) == "("
}

# True when c continues a redirection word rather than starting an operator:
# the `&` of `2>&1`, `>&2`, or `&>log`, or the `|` of `>|`.
function joins_redirection(line, i, c) {
  if (c == "&") {
    return lex_tok ~ /[<>]$/ || substr(line, i + 1, 1) == ">"
  }
  return c == "|" && lex_tok ~ />$/
}

# Count the parentheses of a `$( )` lifted out of double quotes; the closer
# that brings the depth back to zero reopens the quote behind it.
function track_lifted_substitution(c) {
  if (lex_resume_quote == "") {
    return
  }
  if (c == "(") {
    lex_sub_depth++
  } else if (c == ")") {
    lex_sub_depth--
    if (lex_sub_depth == 0) {
      lex_quote = lex_resume_quote
      lex_resume_quote = ""
    }
  }
}

# A character inside quotes: the closer ends the quote, a double-quote
# backslash escapes, a `$(` inside double quotes suspends the quote so the
# substitution it opens is lexed as a command, anything else joins the word.
function quoted_char(line, i, c) {
  if (c == lex_quote) {
    lex_quote = ""
    return 0
  }
  if (lex_quote == "\"" && c == "\\") {
    lex_tok = lex_tok substr(line, i + 1, 1)
    return 1
  }
  if (lex_quote == "\"" && c == "$" && substr(line, i + 1, 1) == "(") {
    lex_resume_quote = lex_quote
    lex_quote = ""
    lex_sub_depth = 0
    return 0
  }
  lex_tok = lex_tok c
  return 0
}

function is_operator(c) {
  return c == ";" || c == "&" || c == "|" || c == "(" || c == ")"
}

function cut_segment() {
  flush_word()
  lex_target_pending = 0
  if (seg_open) {
    nsegs++
    seg_open = 0
  }
}

# Record the pending token as a word: its segment, and whether it is a
# redirection or the target word a bare redirection operator announced.
function flush_word() {
  if (lex_tok != "") {
    nwords++
    words[nwords] = lex_tok
    seg[nwords] = nsegs
    redirect[nwords] = lex_target_pending || is_redirection(lex_tok)
    lex_target_pending = is_bare_redirection(lex_tok)
    seg_open = 1
  }
  lex_tok = ""
}

# A redirection word: an optional descriptor, then `<` or `>`, then whatever
# it targets or nothing -- `>log`, `2>&1`, `<in`, `>>`, `<<EOF` -- or the
# `&>` form.
function is_redirection(word) {
  return word ~ /^[0-9]*[<>]/ || word ~ /^&>/
}

# A redirection operator standing alone, whose target is the following word:
# `>`, `>>`, `<`, `2>`, `<>`, `>|`, `&>`, and the heredoc `<<` or `<<-`.
function is_bare_redirection(word) {
  return word ~ /^[0-9]*(>>?|<>?|>\||<<-?)$/ || word ~ /^&>>?$/
}

# True when word i takes part in its command: not a redirection, nor the
# target word of one.
function is_command_word(i) {
  return !redirect[i]
}

# Arm the heredoc skip when this record's words open one: << followed by the
# delimiter word, or a word carrying the operator and its delimiter (the
# quotes already bound away).
function note_heredoc_open(__i) {
  for (__i = 1; __i <= nwords; __i++) {
    if (words[__i] == "<<" || words[__i] == "<<-") {
      in_heredoc = words[__i + 1]
      return
    }
    if (is_heredoc_word(words[__i])) {
      in_heredoc = heredoc_delimiter(words[__i])
      return
    }
  }
}

# True when word carries a heredoc operator and its delimiter: `<<EOF`,
# `<<-EOF`, or the operator glued to the word before it, as in `:<<'DOC'`.
# A here-string (`<<<`) is not one.
function is_heredoc_word(word) {
  return word ~ /<<-?[^<]/ && word !~ /<<</
}

# The delimiter a heredoc word carries: everything after its operator.
function heredoc_delimiter(word, __delim) {
  __delim = word
  sub(/^.*<<-?/, "", __delim)
  return __delim
}

# The index of segment s's command word — the first word that is not an
# environment assignment or a command wrapper — or 0 when the segment is
# empty.
function command_index(s, __i) {
  for (__i = 1; __i <= nwords; __i++) {
    if (seg[__i] != s) {
      continue
    }
    if (!is_command_word(__i)) {
      continue
    }
    if (words[__i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/) {
      continue
    }
    if (is_wrapper(words[__i])) {
      continue
    }
    return __i
  }
  return 0
}

function is_wrapper(word) {
  return word == "sudo" || word == "doas" || word == "env" || \
    word == "command" || word == "exec" || word == "nohup" || \
    word == "nice" || word == "time"
}

# True when the word names the given program, bare or path-qualified.
function is_program(word, name) {
  return word == name || word ~ ("/" name "$")
}

in_heredoc != "" {
  trimmed = $0
  gsub(/^[ \t]+|[ \t]+$/, "", trimmed)
  if (trimmed == in_heredoc) {
    in_heredoc = ""
  }
  next
}

{
  shell_lex($0)
  note_heredoc_open()
}
