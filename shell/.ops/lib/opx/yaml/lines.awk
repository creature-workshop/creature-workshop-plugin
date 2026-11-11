# lines.awk -- the lines of a YAML document as the reader walks them: each
# line's indentation and its text with the comment taken off, and the line
# the reader stands on.
#
#   Y_N           how many lines the document has
#   Y_RAW[i]      line i as written, which a block scalar reads
#   Y_INDENT[i]   the spaces line i starts with
#   Y_TEXT[i]     line i past its indentation, comment and trailing spaces
#                 off, empty for a line that holds nothing
#   Y_POS         the line the reader stands on
#
#   "  key: 'a # b'  # note"  ->  Y_INDENT 2, Y_TEXT "key: 'a # b'"

# Dies naming the line the reader stands on and why it cannot read it.
function yaml_refuse(why) {
  printf "opx: yaml line %d: %s: %s\n", Y_POS, why, Y_RAW[Y_POS] > "/dev/stderr"
  FAILED = 1
  exit 3
}

# Keeps one line of the document as written.
function yaml_keep_line(raw) {
  Y_RAW[++Y_N] = raw
}

# The spaces a line starts with.
function yaml_indent_of(raw) {
  match(raw, /^ */)
  return RLENGTH
}

# Whether a quote character at position i of text opens a quoted scalar: it
# does at the start of a value, and inside a word ("don't") it is a letter.
function yaml_opens_quote(text, i) {
  return i == 1 || substr(text, i - 1, 1) ~ /[ \[{,]/
}

# The position just past the quoted scalar that opens at position i of text,
# or 0 when the line ends before the quote closes.
function yaml_quote_end(text, i, __quote, __c) {
  __quote = substr(text, i, 1)
  for (i++; i <= length(text); i++) {
    __c = substr(text, i, 1)
    if (__c == "\\" && __quote == "\"") {
      i++
    } else if (__c == __quote && substr(text, i + 1, 1) == __quote && __quote == "'") {
      i++
    } else if (__c == __quote) {
      return i + 1
    }
  }
  return 0
}

# Text with its comment taken off: a "#" that starts the text or follows a
# space, outside any quoted scalar.
function yaml_without_comment(text, __i, __c, __end) {
  for (__i = 1; __i <= length(text); __i++) {
    __c = substr(text, __i, 1)
    if ((__c == "\"" || __c == "'") && yaml_opens_quote(text, __i)) {
      __end = yaml_quote_end(text, __i)
      if (__end == 0) {
        return text
      }
      __i = __end - 1
    } else if (__c == "#" && (__i == 1 || substr(text, __i - 1, 1) == " ")) {
      return substr(text, 1, __i - 1)
    }
  }
  return text
}

# Text with the spaces at its end taken off.
function yaml_rtrim(text) {
  sub(/[ \t]+$/, "", text)
  return text
}

# Text with the spaces at both ends taken off.
function yaml_trim(text) {
  sub(/^[ \t]+/, "", text)
  return yaml_rtrim(text)
}

# Reads every kept line's indentation and text, and stands on the first.
function yaml_read_lines(__i) {
  for (__i = 1; __i <= Y_N; __i++) {
    Y_INDENT[__i] = yaml_indent_of(Y_RAW[__i])
    Y_TEXT[__i] = yaml_rtrim(yaml_without_comment(substr(Y_RAW[__i], Y_INDENT[__i] + 1)))
  }
  Y_POS = 1
}

# Steps over the lines that hold nothing.
function yaml_skip_blank() {
  while (Y_POS <= Y_N && Y_TEXT[Y_POS] == "") {
    Y_POS++
  }
}

# Whether the next line that holds something sits at indent. A tab in its
# indentation is refused, since YAML indents with spaces alone.
function yaml_at(indent) {
  yaml_skip_blank()
  if (Y_POS > Y_N) {
    return 0
  }
  if (Y_TEXT[Y_POS] ~ /^\t/) {
    yaml_refuse("a tab in the indentation")
  }
  return Y_INDENT[Y_POS] == indent
}
