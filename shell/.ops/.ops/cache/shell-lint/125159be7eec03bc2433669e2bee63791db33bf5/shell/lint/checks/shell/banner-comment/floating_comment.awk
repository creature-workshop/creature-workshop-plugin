# Flags free-floating comment runs: a run of whole-line comments followed by a
# blank line or end of file instead of code. A comment earns its place by
# documenting the thing directly beneath it; a run that touches nothing is a
# section label, and a section label is a banner whatever it is drawn with.
# The banners-mean-split rule wants that boundary made real -- its own file --
# instead of labelled. Loaded with the scanner runtime, once per file:
# `awk -v fname=<name> -f scan.awk -f floating_comment.awk`.
#
# The file preamble is exempt: the comment runs above the first code line --
# the shebang, directives, and the top-of-file module doc. The first code
# line ends the preamble whatever the language, so a label parked between
# the imports, the constants, or anywhere further down flags like any other.
# Directive comments (shellcheck, bats tags, banner-lint waivers) configure
# tooling rather than document code, so a run of them alone never flags, and
# heredoc bodies are skipped. Inline trailing comments sit on code lines and
# are out of scope.
#
# A '# banner-lint: allow' marker on any line of the run, or within the three
# lines above its first line, exempts the run.
#
# Emits "<name>:<lineno>: <message>" anchored to the run's first flaggable
# line. Vars: -v fname=<display name> (default FILENAME).

function is_blank_line(line) {
  return (line ~ /^[ \t]*$/)
}

# True when LINE is a directive comment: configuration a tool reads
# (shellcheck, bats tags, banner-lint waivers), not commentary about code.
function is_directive_comment(line) {
  if (line ~ /^[ \t]*#[ \t]*shellcheck[ \t]/) {
    return 1
  }
  if (line ~ /^[ \t]*#[ \t]*bats[ \t]+(file_tags|test_tags)[=:]/) {
    return 1
  }
  if (line ~ /banner-lint:[ \t]*allow/) {
    return 1
  }
  return 0
}

# Starts or extends the current comment run. The run reports at its first
# non-directive line, so a run of directives alone has nothing to report.
function take_comment(line) {
  if (run_start == 0) {
    run_start = FNR
  }
  if (run_report == 0 && !is_directive_comment(line)) {
    run_report = FNR
  }
}

# Discards the current run: code followed it, so it is a doc comment.
function drop_run() {
  run_start = 0
  run_report = 0
}

# Ends the current run at a blank line or EOF: nothing below claims it, so it
# is floating. Reports unless the run sits in the preamble, holds only
# directives, or is covered by an allow marker.
function flush_floating_run() {
  if (run_report > 0 && !in_preamble && run_start > allow_until) {
    note(run_report, "floating comment; a whole-line comment documents the code directly beneath it -- attach it, fold it into the file doc, or split the file (banners-mean-split)")
  }
  drop_run()
}

# Reset per-file state so the trailing-run check cannot leak across runs.
# allow_until is the last line number covered by the most recent allow marker.
FNR == 1 {
  in_heredoc = 0
  allow_until = 0
  in_preamble = 1
  run_start = 0
  run_report = 0
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

  if (is_comment($0)) {
    take_comment($0)
    next
  }

  if (is_blank_line($0)) {
    flush_floating_run()
    next
  }

  in_preamble = 0
  drop_run()

  if (opens_heredoc($0)) {
    in_heredoc = 1
  }
}

END {
  flush_floating_run()
}
