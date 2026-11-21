# Scans a shell source for structs-boundary violations, emitting
#   <file>:<lineno>:<source line>
# for each line the loaded detector rejects. Load the shared runtime and one
# detector first: `awk -f scan.awk -f <detector>.awk -f boundary_scan.awk`.
#
# Heredoc bodies are skipped, because their contents are prose or embedded
# programs rather than code the rules apply to: a DOC block that mentions "{}"
# is documenting the representation, not spelling a literal to rewrite. Comments
# are stripped before the detector sees a line, and a `# structs-lint: allow`
# marker exempts its own line and the next three. The marker names no rule: it
# exempts the line from whichever detector is loaded. Per-rule markers wait until
# silencing one rule while keeping another is something a file actually needs.
#
# A finding sits on the line the detector rejected unless the detector anchors
# it elsewhere by setting violation_line and violation_text before returning
# true -- a multi-line shape reported at its head. An anchored finding is
# exempt when the allow marker covers either line, and in scope when either
# line was added.
# A detector whose findings only settle later, several at one line, reports
# them itself through report_finding and returns false: each is anchored to
# the line it concerns and read for the marker and the filter the same way.
#
# Vars: -v fname=<display name> (default FILENAME, so piped input can be
# labelled); -v added=<csv of line numbers> restricts output to those lines (the
# --added-only mode).

# True when <line> is in scope to report: either no added-line filter is set, or
# the line was among those added.
function in_scope(line) {
  return (!have_filter || (line in added_set))
}

# The line a finding is reported at: the detector's anchor when it set one,
# else the current line.
function anchored_line() {
  return (violation_line > 0 ? violation_line : FNR)
}

# The source text printed with a finding, matching anchored_line.
function anchored_text() {
  return (violation_line > 0 ? violation_text : $0)
}

# Prints the finding at LINE with TEXT unless an allow marker covers it or the
# rejected line, or the added-line filter names neither.
function report_finding(line, text) {
  if (line <= allow_until || FNR <= allow_until) {
    return
  }
  if (!in_scope(line) && !in_scope(FNR)) {
    return
  }
  printf "%s:%d:%s\n", display_name(), line, text
}

BEGIN {
  have_filter = (added != "")
  if (have_filter) {
    __n = split(added, __a, ",")
    for (__i = 1; __i <= __n; __i++) {
      if (__a[__i] != "") {
        added_set[__a[__i] + 0] = 1
      }
    }
  }
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

  if ($0 ~ /structs-lint:[ \t]*allow/) {
    allow_until = FNR + 3
  }

  # The opener line is real code: check it below, then skip its body.
  if (opens_heredoc($0)) {
    in_heredoc = 1
  }

  stripped = $0
  sub(/#.*/, "", stripped)

  if (lint_is_violation(stripped)) {
    report_finding(anchored_line(), anchored_text())
    violation_line = 0
  }
}
