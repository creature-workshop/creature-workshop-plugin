# Reads markdown on stdin and prints its prose as a single normalized line: the
# text a reader actually reads, measured so the count reflects words rather than
# formatting. Fenced code, blockquotes, HTML comments, images, URLs, and markup
# punctuation are dropped; link text and the text inside HTML tags are kept, so
# neither a citation nor a <details> wrapper buys a discount. Runs of whitespace
# collapse to one space.
#
# Code is free in whichever notation carries it -- a fence, a backtick span, or a
# <pre> or <code> container -- so that reaching for HTML neither adds cost nor
# escapes it. The fence and span readers come from lines.awk, shared with the
# program that strips code for a reader of declarations.

# Removes HTML comments from s, opening or closing the multi-line comment state
# as the delimiters demand. A comment that opens without closing swallows the
# rest of the line.
function strip_html_comments(s, __at, __rest, __closes_at) {
  if (in_comment) {
    __closes_at = index(s, "-->")
    if (__closes_at == 0) {
      return ""
    }
    in_comment = 0
    s = substr(s, __closes_at + 3)
  }
  while ((__at = index(s, "<!--")) > 0) {
    __rest = substr(s, __at + 4)
    __closes_at = index(__rest, "-->")
    if (__closes_at == 0) {
      in_comment = 1
      return substr(s, 1, __at - 1)
    }
    s = substr(s, 1, __at - 1) substr(__rest, __closes_at + 3)
  }
  return s
}

# Position of the earliest <pre> or <code> opener in s, recording which tag opens
# there so the matching closer can be found. Zero when neither opens. The trailing
# character class holds the tag to its own name, leaving <precious> alone.
function html_code_open_at(s, __pre_at, __code_at) {
  __pre_at = match(s, /<pre[ \t>]/) ? RSTART : 0
  __code_at = match(s, /<code[ \t>]/) ? RSTART : 0

  if (__pre_at > 0 && (__code_at == 0 || __pre_at < __code_at)) {
    html_code_tag = "pre"
    return __pre_at
  }
  if (__code_at > 0) {
    html_code_tag = "code"
    return __code_at
  }
  return 0
}

# Removes the content of HTML code containers from s, so that code wrapped in
# <pre> or <code> costs what fenced code costs: nothing. A container that opens
# without closing swallows the lines that follow, as an unclosed fence does.
function strip_html_code(s, __at, __rest, __closer, __closes_at) {
  if (in_html_code) {
    __closer = "</" html_code_tag ">"
    __closes_at = index(s, __closer)
    if (__closes_at == 0) {
      return ""
    }
    in_html_code = 0
    s = substr(s, __closes_at + length(__closer))
  }
  while ((__at = html_code_open_at(s)) > 0) {
    __closer = "</" html_code_tag ">"
    __rest = substr(s, __at)
    __closes_at = index(__rest, __closer)
    if (__closes_at == 0) {
      in_html_code = 1
      return substr(s, 1, __at - 1)
    }
    s = substr(s, 1, __at - 1) substr(__rest, __closes_at + length(__closer))
  }
  return s
}

# Restores the characters that HTML entities stand for, so that a word spelled with
# one is charged for what it renders as rather than for how it is escaped. Only the
# entities with an unambiguous single-character meaning are decoded; the rest are
# left as written. Decoding last keeps a decoded < from reading as a tag.
function decode_entities(s) {
  gsub(/&nbsp;/, " ", s)
  gsub(/&lt;/, "<", s)
  gsub(/&gt;/, ">", s)
  gsub(/&quot;/, "\"", s)
  gsub(/&#39;/, "'", s)
  gsub(/&amp;/, "\\&", s)
  return s
}

# True for a line that carries no prose: a blockquote, a link definition, a
# horizontal rule or setext underline, or a table's alignment row.
#
# The rule patterns spell their repetition out rather than using an {n,}
# interval, which the awk on some platforms matches as literal text.
function is_dropped_line(s) {
  if (match(s, /^[ \t]*>/)) {
    return 1
  }
  if (match(s, /^[ \t]*\[[^]]+\][ \t]*:[ \t]*[^ \t]/)) {
    return 1
  }
  if (match(s, /^[ \t]*(---+|===+|\*\*\*+|___+)[ \t]*$/)) {
    return 1
  }
  if (is_table_separator(s)) {
    return 1
  }
  return 0
}

# Reduces s to the text a reader sees: images vanish, links and reference links
# keep their visible text, URLs and HTML tags vanish.
function strip_links_and_tags(s, __match_text) {
  gsub(/!\[[^]]*\]\([^()]*\)/, "", s)
  gsub(/!\[[^]]*\]\[[^][]*\]/, "", s)

  while (match(s, /\[[^][]*\]\([^()]*\)/) || match(s, /\[[^][]*\]\[[^][]*\]/)) {
    __match_text = substr(s, RSTART + 1, RLENGTH - 1)
    sub(/\].*$/, "", __match_text)
    s = substr(s, 1, RSTART - 1) __match_text substr(s, RSTART + RLENGTH)
  }

  gsub(/<[^ \t>]+:\/\/[^ \t>]*>/, "", s)
  gsub(/[a-zA-Z][a-zA-Z0-9+.-]*:\/\/[^ \t]+/, "", s)
  gsub(/<\/?[A-Za-z][^>]*>/, "", s)
  return s
}

# Removes the punctuation that marks a line's role rather than reading as prose:
# heading hashes, list bullets, task checkboxes, and table cell separators.
function strip_line_markers(s) {
  sub(/^[ \t]*#+[ \t]+/, "", s)
  sub(/^[ \t]*([-*+]|[0-9]+[.)])[ \t]+/, "", s)
  sub(/^\[[ xX]\][ \t]*/, "", s)
  gsub(/\|/, " ", s)
  return s
}

{
  # Code notation is settled before HTML containers so that a <pre> shown as an
  # example -- fenced or in a backtick span -- reads as the sample it is, rather
  # than opening a container that swallows the prose after it.
  line = strip_html_comments($0)
  if (is_code_fence(line)) {
    next
  }
  if (in_fence) {
    next
  }
  if (is_dropped_line(line)) {
    next
  }
  line = strip_html_code(strip_code_spans(line))

  line = squeeze(decode_entities(strip_line_markers(strip_links_and_tags(line))))
  if (line == "") {
    next
  }

  prose = (prose == "" ? line : prose " " line)
}

END { print prose }
