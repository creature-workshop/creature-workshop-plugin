#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/api.sh"

: <<'MODULE'
The indent check: the leading whitespace of every shell line, at the width
and tab policy lint.json sets, with heredoc bodies exempt.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__indent__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/indent"

: <<'PUB_FUN'
  Line-level indentation check for shell sources, backed by
  indent_scan.awk (which exempts heredoc bodies, so doc-comments and
  embedded usage text are never policed).

  <opts>.config is the repository's lint.json: its `indent.width` is the
  required leading-space multiple (2 by default) and `indent.tabs` whether
  leading tabs are allowed (false by default). Trailing whitespace is always
  rejected.

  Usage: lint__checks__shell__indent__run <opts> <files...>

  Returns 0 when every file is clean, 1 otherwise (offenders printed to stderr).
PUB_FUN
lint__checks__shell__indent__run() {
  @obj __lint__checks__shell__indent__run__obj_1
  @get lint__checks__shell__indent__run__config "$1" '.config' "$__lint__checks__shell__indent__run__obj_1"
  lint__checks__shell__indent__run__width="$(lint__config__indent_width "$lint__checks__shell__indent__run__config")"
  lint__checks__shell__indent__run__tabs="$(lint__config__allow_tabs "$lint__checks__shell__indent__run__config")"
  lint__checks__shell__indent__run__allow_tabs="$(lint__awk_flag "$lint__checks__shell__indent__run__tabs")"
  shift

  lint__checks__shell__indent__run__hits="$(lint__call_with_existing __lint__checks__shell__indent__scan "$@")"
  @defined "$lint__checks__shell__indent__run__hits" || return 0

  log "$lint__checks__shell__indent__run__hits"
  return 1
}

: <<'FUN'
Scans <files...> in one awk for indentation findings, at the width and tab
policy the run read from the config. scan.awk, from shell-scan, is the
shared scanner runtime (heredoc tracking and the note emitter).
FUN
__lint__checks__shell__indent__scan() {
  awk \
    -v width="$lint__checks__shell__indent__run__width" \
    -v allow_tabs="$lint__checks__shell__indent__run__allow_tabs" \
    -f "$SHELL_SCAN_DIR/shell/scan/scan.awk" \
    -f "$__lint__checks__shell__indent__DIR/indent_scan.awk" \
    "$@"
}
