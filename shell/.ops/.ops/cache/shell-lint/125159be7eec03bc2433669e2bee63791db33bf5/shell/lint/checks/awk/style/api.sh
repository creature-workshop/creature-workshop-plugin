#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/api.sh"

: <<'MODULE'
The awk-style check: braced control-flow bodies, prefixed locals and the
rules below the functions, over the awk lexer the awk-reading detectors
share.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__awk__style__DIR="$SHELL_LINT_DIR/shell/lint/checks/awk/style"

: <<'PUB_FUN'
  Flags awk that breaks the house style: an `if`/`else`/`for`/`while` body
  without braces, a wide-gap local parameter, or an unprefixed parameter that
  sits after a local. Pattern-action rules and fence/container globals are not
  findings. The scanner skips strings, regexes, and `#` comments; it is
  conservative and will miss a rare site rather than flag a literal.

  Usage: lint__checks__awk__style__run <opts> <files...>

  <opts> is the run's options object; this check reads nothing from it.

  Every finding in every file is reported before the non-zero return.
  Returns 0 when every file is clean, 1 otherwise (offenders printed to stderr).
PUB_FUN
lint__checks__awk__style__run() {
  shift
  lint__checks__awk__style__run__hits="$(lint__call_with_existing __lint__checks__awk__style__scan "$@")"
  @defined "$lint__checks__awk__style__run__hits" || return 0

  log "$lint__checks__awk__style__run__hits"
  return 1
}

: <<'FUN'
Scans <files...> in one awk for awk house-style findings.
FUN
__lint__checks__awk__style__scan() {
  awk \
    -f "$SHELL_SCAN_DIR/shell/scan/scan.awk" \
    -f "$SHELL_LINT_DIR/shell/lint/lib/awk_lex.awk" \
    -f "$__lint__checks__awk__style__DIR/awk_style_scan.awk" \
    "$@"
}
