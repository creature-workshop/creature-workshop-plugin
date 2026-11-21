#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/checks/shell/comments.sh"

: <<'MODULE'
The doc-block-tracker check: a detector over the shell-scan scanner and the doc-block
model, run through the comment checks' shared audit.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__doc_block_tracker__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/doc-block-tracker"

: <<'PUB_FUN'
  Rejects a work-tracker marker inside a doc block. A doc block states a
  contract, and someone reading it to learn what the unit promises is not the
  audience for work that has not happened yet. Beside a line of code the same
  marker is fine: there it addresses whoever edits that line.

  Usage: lint__checks__shell__doc_block_tracker__run <opts> <files...>

  <opts> is the run's options object; this check reads nothing from it.

  Returns 0 if no doc block carries one, 1 otherwise (offenders printed to
  stderr).
PUB_FUN
lint__checks__shell__doc_block_tracker__run() {
  lint__checks__shell__comments__audit "$__lint__checks__shell__doc_block_tracker__DIR/doc_block_tracker.awk" "$@"
}
