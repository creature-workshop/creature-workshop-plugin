# Flags multi-line `#` comment doc-blocks that document a function: a run of two
# or more consecutive `#` comment lines immediately followed by a function
# definition. Per the shell house style those must be heredoc (`: <<'DOC' ...
# DOC`) doc blocks, not `#` comments. Loaded with the shared scanner runtime:
# `awk -f scan.awk -f doc_comment_scan.awk`.
#
# Heredoc bodies are skipped (their `#` lines are literal text, not comments);
# the shebang and `# shellcheck` directives never count as doc lines. A
# `# doc-comment-check: allow` marker on a block, or within three lines above it,
# exempts it.
#
# Emits "<name>:<lineno>: <message>" anchored to the block's first line.
# Vars: -v fname=<display name> (default FILENAME); -v added=<csv of line
# numbers> restricts output to blocks whose first line is in the set (the
# --added-only mode), while empty/unset emits every offending block.

# A whole-line `#` comment that counts as documentation prose -- not the shebang
# and not a `# shellcheck` directive.
function is_doc_comment(line) {
  if (line ~ /^[ \t]*#!/) {
    return 0
  }
  if (line ~ /^[ \t]*#[ \t]*shellcheck/) {
    return 0
  }
  return (line ~ /^[ \t]*#/)
}

# True when a block starting at <start> is in scope to report: either no
# added-line filter is set, or its first line was among the added lines.
function in_scope(start) {
  return (!have_filter || (start in added_set))
}

# Processes one record: tracks the heredoc state and the current run of doc
# comment lines, flagging a run of two or more that sits immediately above a
# function definition (unless an allow marker covers it).
function scan_line() {
  if (in_heredoc) {
    if (closes_heredoc($0)) {
      in_heredoc = 0
    }
    run_len = 0
    return
  }

  if ($0 ~ /doc-comment-check:[ \t]*allow/) {
    allow_at = FNR
  }

  if (is_doc_comment($0)) {
    if (run_len == 0) {
      run_start = FNR
    }
    run_len++
    return
  }

  # A non-comment line ends the pending run. A run of two or more lines sitting
  # immediately above a function definition is a function doc-block that must be
  # a heredoc -- unless an allow marker covers it (within three lines above the
  # block start, or anywhere inside it).
  if (run_len >= 2 && is_func_def($0) && allow_at < run_start - 3 && in_scope(run_start)) {
    note(run_start, "multi-line # doc-comment for a function; use a heredoc doc block (: <<'PUB_FUN' ... PUB_FUN, or FUN)")
  }

  run_len = 0

  if (opens_heredoc($0)) {
    in_heredoc = 1
  }
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

# Reset per-file state so a single awk run can scan many files. allow_at holds
# the line of the most recent allow marker (far negative when none seen).
FNR == 1 {
  in_heredoc = 0
  run_len = 0
  run_start = 0
  allow_at = -100
}

{ scan_line() }
