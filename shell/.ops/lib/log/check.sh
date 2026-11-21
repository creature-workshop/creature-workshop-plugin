#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/api.sh"

: <<'FRAGMENT'
The println check. A printf of one argument with the format '%s\n' is
println; the detector is lib/log/printf_line.awk over the shared scanner
runtime, so a heredoc body is never a call.
FRAGMENT

# CONST: The directory of the detector, absolute so the caller's cwd does not matter.
__log__check__DIR="$SHELLOPS_DIR/lib/log"

# CONST: The scanner runtime the detector is loaded with; it tracks heredocs.
__log__check__RUNTIME="$SHELL_SCAN_DIR/shell/scan/scan.awk"

: <<'FUN'
Prints every finding the detector reports in <files...>, as
"<file>:<lineno>: <why>", every file in one awk.
FUN
__log__check__scan_files() {
  awk \
    -f "$__log__check__RUNTIME" \
    -f "$__log__check__DIR/printf_line.awk" \
    "$@"
}

: <<'FUN'
Runs the detector over <files...>, printing every offender rather than
stopping at the first.

Returns 0 when every file is clean, 1 otherwise.
FUN
__log__check__audit() {
  __log__check__audit__hits="$(lint__call_with_existing __log__check__scan_files "$@")"
  @defined "$__log__check__audit__hits" || return 0

  log "$__log__check__audit__hits"
  return 1
}

: <<'PUB_FUN'
Rejects printf '%s\n' or printf "%s\n" with one argument, where println
prints that line. A second argument is a different call and stays. A
redirection and its target are not arguments.

Usage: log__check__no_single_printf <opts> <files...>

<opts> is the run's options object; this check reads nothing from it.

A call the verb cannot replace keeps a `# println-check: allow` on the
line, or within the three lines above it.

Returns 0 when every file is clean, 1 otherwise (offenders printed to
stderr).
PUB_FUN
log__check__no_single_printf() {
  shift
  __log__check__audit "$@"
}
