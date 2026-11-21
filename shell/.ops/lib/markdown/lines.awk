# The classifications every program that reads markdown shares: the ones in
# this module, and the decision-record checks in shell-lint, which
# loads this file ahead of its own programs.
#
# They have to agree. markdown__has_leading_quote decides whether a comment is a
# reply and markdown__strip_leading_quote then removes the quotation it found, so
# two spellings of "quoted line" would let the first say yes while the second
# removed nothing -- which downstream is indistinguishable from a comment that
# never had a quotation.
#
# The same holds for code, and there it has already gone wrong: what
# markdown__strip_code removes decides which text can declare an issue closed,
# and what strip_prose removes decides how long that text is judged to be. Two
# ideas of "code" meant a backtick span was a quotation to one reader and a
# sentence to the other, and an issue nobody mentioned went to Done for it.

function is_blank(line) {
  return line ~ /^[[:space:]]*$/
}

function is_quoted(line) {
  return line ~ /^[[:space:]]*>/
}

# True when line is an ATX heading: one to six hashes, then a space.
function is_heading(line) {
  return line ~ /^[ \t]*#+[ \t]+/
}

# The level of a heading line, the count of its leading hashes; 0 for a line
# that is not a heading.
#
#     heading_level("## Glossary")  ->  2
function heading_level(line, __hashes) {
  if (!is_heading(line)) {
    return 0
  }
  match(line, /#+/)
  return RLENGTH
}

# The text of a heading line: the hashes and the whitespace around them removed,
# along with the closing hashes markdown allows.
#
#     heading_text("## Glossary ##")  ->  "Glossary"
function heading_text(line, __text) {
  __text = line
  sub(/^[ \t]*#+[ \t]+/, "", __text)
  sub(/[ \t]+#+[ \t]*$/, "", __text)
  sub(/[ \t]+$/, "", __text)
  return __text
}

# True when line is a row of a pipe table: it opens on a pipe.
function is_table_row(line) {
  return line ~ /^[ \t]*\|/
}

# True when line is a pipe table's alignment row, the one under its header:
# pipes, dashes, colons and spaces, and nothing else.
#
#     is_table_separator("|---|:--:|")  ->  1
function is_table_separator(line) {
  return line ~ /^[ \t|:-]+$/ && index(line, "|") > 0
}

# True when text holds an inline link, [text](target); RSTART and RLENGTH then
# say where the first one is, so a caller can take it and look past it.
function has_link(text) {
  return match(text, /\[[^][]*\]\([^()]*\)/)
}

# The text of an inline link.
#
#     link_text("[Table 1: Kinds](tables/kinds.md)")  ->  "Table 1: Kinds"
function link_text(link) {
  return substr(link, 2, index(link, "](") - 2)
}

# The target of an inline link.
#
#     link_target("[Table 1: Kinds](tables/kinds.md)")  ->  "tables/kinds.md"
function link_target(link, __at) {
  __at = index(link, "](")
  return substr(link, __at + 2, length(link) - __at - 2)
}

# True when line is a code fence, toggling the fence state as a side effect. A
# closing fence must repeat the opening character at least as many times, so a
# ~~~ line inside a ``` block reads as content rather than a terminator, and a
# ``` line inside a ```` block is the sample it looks like.
function is_code_fence(line, __fence, __ch, __run) {
  if (!match(line, /^[ \t]*(```|~~~)/)) {
    return 0
  }

  __fence = line
  sub(/^[ \t]*/, "", __fence)
  __ch = substr(__fence, 1, 1)
  __run = 0
  while (substr(__fence, __run + 1, 1) == __ch) {
    __run++
  }

  if (!in_fence) {
    in_fence = 1
    fence_char = __ch
    fence_run = __run
    return 1
  }
  if (__ch == fence_char && __run >= fence_run) {
    in_fence = 0
  }
  return 1
}

# Removes inline code spans from line. A run of backticks closes on a run of
# equal length, matching how markdown lets `` ` `` hold a literal backtick. An
# unclosed run is treated as stray punctuation and its text is kept.
function strip_code_spans(line, __kept, __at, __rest, __run, __delim, __body, __closes_at) {
  __kept = ""
  while ((__at = index(line, "`")) > 0) {
    __kept = __kept substr(line, 1, __at - 1)
    __rest = substr(line, __at)
    __run = 0
    while (substr(__rest, __run + 1, 1) == "`") {
      __run++
    }
    __delim = substr(__rest, 1, __run)
    __body = substr(__rest, __run + 1)
    __closes_at = index(__body, __delim)
    if (__closes_at == 0) {
      line = __body
      break
    }
    line = substr(__body, __closes_at + __run)
  }
  return __kept line
}

# Collapses whitespace runs to one space and trims the ends, so that two
# programs printing prose as one line agree on what one line looks like.
function squeeze(s) {
  gsub(/[ \t]+/, " ", s)
  sub(/^ /, "", s)
  sub(/ $/, "", s)
  return s
}
