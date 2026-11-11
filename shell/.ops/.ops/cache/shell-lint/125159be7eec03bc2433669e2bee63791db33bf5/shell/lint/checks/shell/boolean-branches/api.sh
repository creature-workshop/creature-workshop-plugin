#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/api.sh"

: <<'MODULE'
The boolean-branches check: a predicate is `@succeeds <condition>` (or
`@fails`), never an if whose then-body is `@true` and whose else-body is
`@false`. The detector is an awk over the shell-scan scanner runtime, so
heredoc bodies are never policed, and it reads a file as statements, so the
shape is found however the lines are laid out.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__boolean_branches__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/boolean-branches"

# CONST: The scanner runtime the detector is loaded with; it tracks the heredocs.
__lint__checks__shell__boolean_branches__RUNTIME="$SHELL_SCAN_DIR/shell/scan/scan.awk"

: <<'FUN'
Prints every finding the detector reports in <files...>, as
"<file>:<lineno>: <why>", every file in one awk.
FUN
__lint__checks__shell__boolean_branches__scan_files() {
  awk \
    -f "$__lint__checks__shell__boolean_branches__RUNTIME" \
    -f "$__lint__checks__shell__boolean_branches__DIR/boolean_branch.awk" \
    "$@"
}

: <<'PUB_FUN'
  Rejects an if whose then-body is `@true` or `@false` alone and whose
  else-body is the other constructor alone: a predicate written by hand,
  where `@succeeds <condition>` (or `@fails`) is the one line that replaces
  it. The finding is reported once, at the `if` line. A guard that prints
  one constructor and returns passes, and so does an if whose condition
  joins commands with && or ||, since @succeeds runs one command.

  Usage: lint__checks__shell__boolean_branches__run <opts> <files...>

  <opts> is the run's options object; this check reads nothing from it.

  Waiver: an if that has to stay is kept with a `# structs-lint: allow`
    comment on, or within three lines above, the if (explaining why).

  Returns 0 if no file carries one, 1 otherwise (offenders printed to
  stderr).
PUB_FUN
lint__checks__shell__boolean_branches__run() {
  shift
  __lint__checks__shell__boolean_branches__run__hits="$(lint__call_with_existing __lint__checks__shell__boolean_branches__scan_files "$@")"
  @defined "$__lint__checks__shell__boolean_branches__run__hits" || return 0

  log "$__lint__checks__shell__boolean_branches__run__hits"
  return 1
}
