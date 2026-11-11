# What the comment detectors share about a doc block, loaded between the
# scanner and one detector:
#   awk -f scan.awk -f doc_block.awk -f <detector>.awk
#
# A doc block is the heredoc the scanner's opens_doc_block recognises, the
# `: <<'LABEL' ... LABEL` form the shell house style uses for module and
# function documentation, its label naming what it documents. The helpers
# here read the labels and the body's shape, so that no two detectors
# disagree about them.

# True when TERM is one of the four labels an assignment doc opens on.
function is_assignment_label(term) {
  return (term == "VAR" || term == "CONST" || term == "PUB_VAR" || term == "PUB_CONST")
}

# Width of LINE's leading whitespace.
function indent_width(line) {
  match(line, /^[ \t]*/)
  return RLENGTH
}

# True when LINE has no non-whitespace content.
function is_blank(line) {
  return (line !~ /[^ \t]/)
}

# True when LINE heads a labelled reference section of a doc block. What follows
# such a heading is a table or a synopsis -- content whose length is set by the
# interface being described, not by how much the author chose to say.
function is_section_heading(line) {
  return (line ~ /^[ \t]*(Usage|Flags|Parameters|Params|Returns|Options|Vars|Example|Examples|Args|Arguments|Environment|Subcommands)([^A-Za-z]|$)/)
}

# The narrowest indentation among BODY's <count> non-blank lines, which is the
# level its prose sits at. Blocks are written flush against the opener in some
# modules and indented as a whole in others, so "indented" only means anything
# relative to the block's own baseline.
function body_baseline(body, count, __i, __narrowest, __width) {
  __narrowest = -1
  for (__i = 1; __i <= count; __i++) {
    if (is_blank(body[__i])) {
      continue
    }
    __width = indent_width(body[__i])
    if (__narrowest < 0 || __width < __narrowest) {
      __narrowest = __width
    }
  }
  return (__narrowest < 0 ? 0 : __narrowest)
}

# How many of BODY's <count> lines are prose: sentences the author wrote about
# the unit, as opposed to the structured reference content a doc legitimately
# carries at any length. Blank lines, section headings, and lines indented past
# the block's baseline (continuations and table rows) are all excluded.
function prose_line_count(body, count, __i, __baseline, __prose) {
  __baseline = body_baseline(body, count)
  __prose = 0
  for (__i = 1; __i <= count; __i++) {
    if (is_blank(body[__i])) {
      continue
    }
    if (indent_width(body[__i]) > __baseline) {
      continue
    }
    if (is_section_heading(body[__i])) {
      continue
    }
    __prose++
  }
  return __prose
}
