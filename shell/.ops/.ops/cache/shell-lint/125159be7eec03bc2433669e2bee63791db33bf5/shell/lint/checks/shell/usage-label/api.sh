#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/checks/shell/comments.sh"

: <<'MODULE'
The usage-label check: a detector over the shell-scan scanner and the doc-block
model, run through the comment checks' shared audit.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__usage_label__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/usage-label"

: <<'PUB_FUN'
  Rejects a usage heredoc that does not open on HELP, and a HELP heredoc that
  is not the usage. Carrying a HELP heredoc is what marks a file as an
  entrypoint (ADR 000039), so the label goes on the usage and on nothing else.

  Usage: lint__checks__shell__usage_label__run <opts> <files...>

  <opts> is the run's options object; this check reads nothing from it.

  Returns 0 if every usage opens on HELP and nothing else does, 1 otherwise
  (offenders printed to stderr).
PUB_FUN
lint__checks__shell__usage_label__run() {
  lint__checks__shell__comments__audit "$__lint__checks__shell__usage_label__DIR/usage_label.awk" "$@"
}
