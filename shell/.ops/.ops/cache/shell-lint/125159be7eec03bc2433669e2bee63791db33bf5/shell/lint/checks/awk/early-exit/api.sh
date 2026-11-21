#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/api.sh"

: <<'MODULE'
The awk-early-exit check: an awk program reads its input to the end before
it exits with an answer, over the awk lexer the awk-reading detectors
share.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__awk__early_exit__DIR="$SHELL_LINT_DIR/shell/lint/checks/awk/early-exit"

: <<'PUB_FUN'
  Flags an awk program that exits with an answer while it has input left to
  read: a bare `exit`, `exit 0` or `exit <expression>` outside BEGIN and END.
  Such a reader closes the pipe on a writer still writing, and under pipefail
  the writer's SIGPIPE fails the pipeline with 141 now and then, whatever the
  answer was. An error exit, `exit` with a non-zero number, is not a finding,
  and neither is an exit below `# early-exit-check: allow`.

  Usage: lint__checks__awk__early_exit__run <opts> <files...>

  <opts> is the run's options object; this check reads nothing from it.

  Every finding in every file is reported before the non-zero return.
  Returns 0 when every file is clean, 1 otherwise (offenders printed to stderr).
PUB_FUN
lint__checks__awk__early_exit__run() {
  shift
  lint__checks__awk__early_exit__run__hits="$(lint__call_with_existing __lint__checks__awk__early_exit__scan "$@")"
  @defined "$lint__checks__awk__early_exit__run__hits" || return 0

  log "$lint__checks__awk__early_exit__run__hits"
  return 1
}

: <<'FUN'
Scans <files...> in one awk for exits that leave input unread.
FUN
__lint__checks__awk__early_exit__scan() {
  awk \
    -f "$SHELL_SCAN_DIR/shell/scan/scan.awk" \
    -f "$SHELL_LINT_DIR/shell/lint/lib/awk_lex.awk" \
    -f "$__lint__checks__awk__early_exit__DIR/awk_early_exit.awk" \
    "$@"
}
