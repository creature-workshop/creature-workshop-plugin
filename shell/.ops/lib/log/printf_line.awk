# Flags a printf of '%s\n' or "%s\n" with one argument, the call println
# stands in for. Loaded with the scanner runtime:
# `awk -f scan.awk -f printf_line.awk`.
#
# Heredoc bodies are skipped, so a doc that names the old spelling is not a
# call. A line continued with a backslash is judged whole, and the finding
# sits on the first line of that continuation. A `# println-check: allow` on
# the line, or within the three lines above it, keeps the call.
#
# One argument is one shell word: a quote, a parameter, or a substitution.
# A redirection and its target are not arguments, and a second word is a
# different call. A printf inside $( ), <( ) or >( ) is a call of its own.
#
# A position is a 1-based index into the line. A function that ends a span
# returns the index just past it.

function skip_blanks(line, position, __char) {
  while (position <= length(line)) {
    __char = substr(line, position, 1)
    if (__char != " " && __char != "\t") {
      return position
    }
    position++
  }
  return position
}

function skip_digits(line, position) {
  while (position <= length(line) && substr(line, position, 1) ~ /[0-9]/) {
    position++
  }
  return position
}

function is_quote(char) {
  return (char == "'" || char == "\"")
}

function is_pair_operator(line, position, __pair) {
  __pair = substr(line, position, 2)
  return (__pair == "&&" || __pair == "||")
}

function at_operator(line, position, __char) {
  if (is_pair_operator(line, position)) {
    return 1
  }
  __char = substr(line, position, 1)
  return (__char ~ /^[|&;(){}]$/)
}

function operator_length(line, position) {
  if (is_pair_operator(line, position)) {
    return 2
  }
  return 1
}

# True when the operator at POSITION puts the next word in command position:
# every one but a closing ) or }.
function operator_opens_command(line, position, __char) {
  if (is_pair_operator(line, position)) {
    return 1
  }
  __char = substr(line, position, 1)
  return (__char ~ /^[;|&({]$/)
}

function at_redir(line, position, __char) {
  __char = substr(line, skip_digits(line, position), 1)
  return (__char == ">" || __char == "<")
}

function is_nested_open(line, position, __pair) {
  __pair = substr(line, position, 2)
  return (__pair == "$(" || __pair == "<(" || __pair == ">(")
}

function is_braced_open(line, position) {
  return (substr(line, position, 2) == "${")
}

# True when POSITION is past the end of the line or at its comment.
function ends_line(line, position) {
  return (position > length(line) || substr(line, position, 1) == "#")
}

# True when no argument starts at POSITION: the line or its comment ends, or
# an operator or a redirection begins.
function ends_arguments(line, position) {
  if (ends_line(line, position)) {
    return 1
  }
  return (at_operator(line, position) || at_redir(line, position))
}

function stops_word(line, position, __char) {
  __char = substr(line, position, 1)
  if (__char == " " || __char == "\t" || __char == "#" || is_quote(__char)) {
    return 1
  }
  return (at_operator(line, position) || at_redir(line, position))
}

# How far CHAR moves the nesting depth of a span opened by OPENER and closed
# by CLOSER.
function depth_change(char, opener, closer) {
  if (char == opener) {
    return 1
  }
  if (char == closer) {
    return -1
  }
  return 0
}

# The index just past the next CLOSER after POSITION, or past the line when
# none closes it.
function past_next(line, position, closer, __offset) {
  __offset = index(substr(line, position + 1), closer)
  if (__offset == 0) {
    return length(line) + 1
  }
  return position + __offset + 1
}

function skip_single_quoted(line, position) {
  return past_next(line, position, "'")
}

function skip_backtick(line, position) {
  return past_next(line, position, "`")
}

# The index just past one piece of a double quote's body at POSITION: an
# escaped character, a substitution, a backtick command, or one character.
function quoted_piece_end(line, position, __char) {
  __char = substr(line, position, 1)
  if (__char == "\\") {
    return position + 2
  }
  if (is_nested_open(line, position)) {
    return nested_end(line, position)
  }
  if (__char == "`") {
    return skip_backtick(line, position)
  }
  return position + 1
}

# A $( ) inside a double quote is its own command, so a quote inside it does
# not close the outer one.
function skip_double_quoted(line, position) {
  position++
  while (position <= length(line) && substr(line, position, 1) != "\"") {
    position = quoted_piece_end(line, position)
  }
  if (position > length(line)) {
    return position
  }
  return position + 1
}

function skip_quoted(line, position) {
  if (substr(line, position, 1) == "'") {
    return skip_single_quoted(line, position)
  }
  return skip_double_quoted(line, position)
}

# The end of the $( ), <( ) or >( ) that opens at POSITION, quotes included.
function nested_end(line, position, __depth, __char) {
  position += 2
  __depth = 1
  while (position <= length(line) && __depth > 0) {
    __char = substr(line, position, 1)
    if (is_quote(__char)) {
      position = skip_quoted(line, position)
      continue
    }
    __depth += depth_change(__char, "(", ")")
    position++
  }
  return position
}

# The end of the ${ } that opens at POSITION.
function braced_end(line, position, __depth) {
  position += 2
  __depth = 1
  while (position <= length(line) && __depth > 0) {
    __depth += depth_change(substr(line, position, 1), "{", "}")
    position++
  }
  return position
}

# The index just past one piece of an unquoted word at POSITION: a
# substitution, a parameter in braces, or one character.
function bare_piece_end(line, position) {
  if (is_nested_open(line, position)) {
    return nested_end(line, position)
  }
  if (is_braced_open(line, position)) {
    return braced_end(line, position)
  }
  return position + 1
}

function bare_word_end(line, position) {
  while (position <= length(line) && !stops_word(line, position)) {
    position = bare_piece_end(line, position)
  }
  return position
}

function word_end(line, position) {
  if (is_quote(substr(line, position, 1))) {
    return skip_quoted(line, position)
  }
  if (is_nested_open(line, position)) {
    return nested_end(line, position)
  }
  if (is_braced_open(line, position)) {
    return braced_end(line, position)
  }
  return bare_word_end(line, position)
}

# The shell word at POSITION. The index just past it is left in
# __printf_line__end.
function take_word(line, position) {
  __printf_line__end = word_end(line, position)
  return substr(line, position, __printf_line__end - position)
}

function skip_redir_target(line, position) {
  if (ends_arguments(line, position)) {
    return position
  }
  return word_end(line, position)
}

function redir_operator_length(pair) {
  if (pair == ">>" || pair == "<<" || pair == "&>") {
    return 2
  }
  return 1
}

# The index just past the redirection at POSITION and its target. A
# descriptor duplication such as 2>&1 carries its target in the operator.
function skip_redir(line, position, __pair) {
  position = skip_digits(line, position)
  __pair = substr(line, position, 2)
  if (__pair == ">&" || __pair == "<&") {
    return skip_digits(line, position + 2)
  }
  position += redir_operator_length(__pair)
  return skip_redir_target(line, skip_blanks(line, position))
}

# The command inside the $( ), <( ) or >( ) that opens at POSITION.
function nested_inner(word, position) {
  return substr(word, position + 2, nested_end(word, position) - position - 3)
}

function nested_has_single_printf(word, position) {
  if (!is_nested_open(word, position)) {
    return 0
  }
  return has_single_printf(nested_inner(word, position))
}

function double_quoted_has_single_printf(word, position) {
  position++
  while (position <= length(word) && substr(word, position, 1) != "\"") {
    if (nested_has_single_printf(word, position)) {
      return 1
    }
    position = quoted_piece_end(word, position)
  }
  return 0
}

# The index just past one piece of a word at POSITION: a quote, a
# substitution, or one character.
function word_piece_end(word, position) {
  if (is_quote(substr(word, position, 1))) {
    return skip_quoted(word, position)
  }
  if (is_nested_open(word, position)) {
    return nested_end(word, position)
  }
  return position + 1
}

function word_piece_has_single_printf(word, position) {
  if (substr(word, position, 1) == "\"") {
    return double_quoted_has_single_printf(word, position)
  }
  return nested_has_single_printf(word, position)
}

# True when a substitution in WORD that no single quote hides holds a
# printf of one argument.
function contains_single_printf(word, __position) {
  __position = 1
  while (__position <= length(word)) {
    if (word_piece_has_single_printf(word, __position)) {
      return 1
    }
    __position = word_piece_end(word, __position)
  }
  return 0
}

function is_line_format(word) {
  return (word == "'%s\\n'" || word == "\"%s\\n\"")
}

# True when exactly one argument follows POSITION, or one of them holds a
# printf of its own. The index where the arguments stop is left in
# __printf_line__end.
function prints_one_argument(line, position, __count, __argument) {
  __count = 0
  position = skip_blanks(line, position)
  while (!ends_arguments(line, position)) {
    __argument = take_word(line, position)
    position = __printf_line__end
    if (contains_single_printf(__argument)) {
      return 1
    }
    __count++
    position = skip_blanks(line, position)
  }
  __printf_line__end = position
  return (__count == 1)
}

# True when the printf whose format starts at POSITION prints '%s\n' with
# one argument, or a substitution in its words does. The index where the
# call's words stop is left in __printf_line__end.
function printf_call_is_single(line, position, __format) {
  position = skip_blanks(line, position)
  if (position > length(line)) {
    __printf_line__end = position
    return 0
  }
  __format = take_word(line, position)
  position = __printf_line__end
  if (contains_single_printf(__format)) {
    return 1
  }
  if (!is_line_format(__format)) {
    __printf_line__end = position
    return 0
  }
  return prints_one_argument(line, position)
}

# True when LINE prints one argument with printf '%s\n' or "%s\n",
# or a substitution inside it does.
function has_single_printf(line, __position, __starts_command, __word) {
  if (index(line, "printf") == 0) {
    return 0
  }
  __position = 1
  __starts_command = 1
  while (__position <= length(line)) {
    __position = skip_blanks(line, __position)
    if (ends_line(line, __position)) {
      return 0
    }
    if (at_operator(line, __position)) {
      __starts_command = operator_opens_command(line, __position)
      __position += operator_length(line, __position)
      continue
    }
    if (at_redir(line, __position)) {
      __position = skip_redir(line, __position)
      continue
    }
    __word = take_word(line, __position)
    __position = __printf_line__end
    if (contains_single_printf(__word)) {
      return 1
    }
    if (__starts_command && __word == "printf") {
      if (printf_call_is_single(line, __position)) {
        return 1
      }
      __position = __printf_line__end
    }
    __starts_command = 0
  }
  return 0
}

function continues_line(line, __last) {
  __last = length(line)
  if (__last == 0 || substr(line, __last, 1) != "\\") {
    return 0
  }
  if (__last >= 2 && substr(line, __last - 1, 1) == "\\") {
    return 0
  }
  return 1
}

function without_cont(line) {
  return substr(line, 1, length(line) - 1)
}

function shown_name(fallback) {
  if (fname != "") {
    return fname
  }
  return fallback
}

function emit(name, at) {
  if (at <= allow_until) {
    return
  }
  printf "%s:%d: %s\n", name, at, "printf '%s\\n' with one argument; println prints that line"
}

function consider(name, at, text) {
  if (has_single_printf(text)) {
    emit(name, at)
  }
}

FNR == 1 {
  if (pending != "") {
    consider(pending_name, pending_at, pending)
    pending = ""
  }
  in_heredoc = 0
  allow_until = 0
}

END {
  if (pending != "") {
    consider(pending_name, pending_at, pending)
  }
}

{
  if (in_heredoc) {
    if (closes_heredoc($0)) {
      in_heredoc = 0
    }
    next
  }

  if ($0 ~ /println-check:[ \t]*allow/) {
    allow_until = FNR + 3
  }

  if (continues_line($0)) {
    if (pending == "") {
      pending_at = FNR
      pending_name = shown_name(FILENAME)
      pending = without_cont($0)
    } else {
      pending = pending without_cont($0)
    }
    next
  }

  if (pending != "") {
    consider(pending_name, pending_at, pending $0)
    pending = ""
  } else {
    consider(shown_name(FILENAME), FNR, $0)
  }

  if (opens_heredoc($0)) {
    in_heredoc = 1
  }
}
