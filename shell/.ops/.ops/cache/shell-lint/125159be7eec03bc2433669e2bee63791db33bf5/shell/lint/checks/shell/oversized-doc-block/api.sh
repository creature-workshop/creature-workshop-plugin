#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/checks/shell/comments.sh"

: <<'MODULE'
The oversized-doc-block check: a detector over the shell-scan scanner and the doc-block
model, run through the comment checks' shared audit.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__oversized_doc_block__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/oversized-doc-block"

: <<'PUB_FUN'
  Rejects a doc block whose prose outgrows what a doc is for. Only prose counts:
  blank lines, labelled sections, and the indented content beneath them are as
  long as the interface they describe, and a cap on those would be a cap on
  documenting an interface properly.

  Usage: lint__checks__shell__oversized_doc_block__run <opts> <files...>

  <opts> is the run's options object; this check reads nothing from it.

  Returns 0 if every block is within its cap, 1 otherwise (offenders printed to
  stderr).
PUB_FUN
lint__checks__shell__oversized_doc_block__run() {
  lint__checks__shell__comments__audit "$__lint__checks__shell__oversized_doc_block__DIR/oversized_doc_block.awk" "$@"
}
