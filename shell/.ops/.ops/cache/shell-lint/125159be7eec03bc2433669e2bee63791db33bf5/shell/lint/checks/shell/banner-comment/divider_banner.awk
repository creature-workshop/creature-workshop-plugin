# Flags comment lines drawn as banners: a run of five or more identical
# divider characters (hyphen, equals sign, hash, or the box-drawing dash)
# after the character that opens the comment. A banner marks a section
# boundary the language cannot enforce, and the banners-mean-split rule wants
# that boundary made real -- its own file -- instead of drawn. Loaded with the
# scanner runtime: `awk -f scan.awk -f divider_banner.awk`.
#
# Only whole-line comments are candidates: a divider run inside code is a
# string or a regex, never a section marker. Heredoc bodies are skipped, so
# usage text and embedded fixtures are never policed -- and a comment line
# never opens a heredoc, however its prose reads. A line covered by a
# '# banner-lint: allow' marker (on it, or within the three lines above) is
# exempt -- that is the escape hatch for a banner that is load-bearing data.
#
# Emits "<name>:<lineno>: <message>" anchored to the offending line.
# Vars: -v fname=<display name> (default FILENAME).

# The comment's text when LINE is a whole-line comment: everything past the
# first `#`. Returns the empty string for code lines, so a lone `#` -- an
# empty comment -- and a non-comment line are both out of scope.
function whole_line_comment_text(line, __text) {
  if (line !~ /^[ \t]*#/) {
    return ""
  }
  __text = line
  sub(/^[ \t]*#/, "", __text)
  return __text
}

# True when TEXT contains five identical divider characters in a row. Checked
# by substring rather than a counted repetition, because a longer run always
# contains the five-run and the box-drawing dash is multi-byte in every
# common awk.
function has_divider_run(text) {
  if (index(text, "-----") > 0) {
    return 1
  }
  if (index(text, "=====") > 0) {
    return 1
  }
  if (index(text, "#####") > 0) {
    return 1
  }
  if (index(text, "─────") > 0) {
    return 1
  }
  return 0
}

function report(line) {
  note(line, "banner comment; a section boundary worth drawing is a file boundary -- split it out (banners-mean-split)")
}

# Reset per-file state so a single awk run can scan many files. allow_until is
# the last line number covered by the most recent allow marker.
FNR == 1 {
  in_heredoc = 0
  allow_until = 0
}

{
  if (in_heredoc) {
    if (closes_heredoc($0)) {
      in_heredoc = 0
    }
    next
  }

  if ($0 ~ /banner-lint:[ \t]*allow/) {
    allow_until = FNR + 3
  }

  if ($0 ~ /^[ \t]*#/) {
    if (has_divider_run(whole_line_comment_text($0)) && FNR > allow_until) {
      report(FNR)
    }
    next
  }

  if (opens_heredoc($0)) {
    in_heredoc = 1
  }
}
