#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/checks/shell/comments.sh"

: <<'MODULE'
The doc-spacing check: a detector over the shell-scan scanner and the doc-block
model, run through the comment checks' shared audit.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__doc_spacing__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/doc-spacing"

: <<'PUB_FUN'
  Rejects a doc block opener or a typed comment with no blank line above it,
  so the eye finds where the entry above ends. The first line of a file and a
  doc below a `#` line, a directive say, need none.

  Usage: lint__checks__shell__doc_spacing__run <opts> <files...>

  <opts> is the run's options object; this check reads nothing from it.

  Returns 0 if every doc sits below a blank line, 1 otherwise (offenders
  printed to stderr).
PUB_FUN
lint__checks__shell__doc_spacing__run() {
  lint__checks__shell__comments__audit "$__lint__checks__shell__doc_spacing__DIR/doc_spacing.awk" "$@"
}
