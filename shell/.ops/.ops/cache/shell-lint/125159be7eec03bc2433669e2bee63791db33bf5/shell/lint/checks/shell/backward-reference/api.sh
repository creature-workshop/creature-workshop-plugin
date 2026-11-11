#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/checks/shell/comments.sh"

: <<'MODULE'
The backward-reference check: a detector over the shell-scan scanner and the doc-block
model, run through the comment checks' shared audit.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__backward_reference__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/backward-reference"

: <<'PUB_FUN'
  Rejects comment prose written about the code's past. A comment describes what
  the code does now -- the reader has the current file and nothing else, so a
  sentence about an earlier shape sends them hunting for something that is not
  there. Doc blocks and `#` comments are both prose; heredoc data is not.

  Usage: lint__checks__shell__backward_reference__run <opts> <files...>

  <opts> is the run's options object; this check reads nothing from it.

  Returns 0 if no comment looks backward, 1 otherwise (offenders printed to
  stderr).
PUB_FUN
lint__checks__shell__backward_reference__run() {
  lint__checks__shell__comments__audit "$__lint__checks__shell__backward_reference__DIR/backward_reference.awk" "$@"
}
