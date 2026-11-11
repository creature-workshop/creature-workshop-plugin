#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/checks/shell/comments.sh"

: <<'MODULE'
The assignment-label check: a detector over the shell-scan scanner and the doc-block
model, run through the comment checks' shared audit.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__assignment_label__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/assignment-label"

: <<'PUB_FUN'
  Rejects a doc above a module-root variable or constant whose label does not
  say what the name is: CONST when the name's last segment is upper case, VAR
  otherwise, with PUB_ in a library file when the name has no leading __
  (ADR 000031). The label is what the lowering reads for the name's kind and
  visibility (ADR 000039), so it has to agree with the name, and one of the
  four labels on a block that documents no root assignment is a finding too.

  Usage: lint__checks__shell__assignment_label__run <opts> <files...>

  <opts> is the run's options object; this check reads the library roots
  from its config, or the defaults.

  Returns 0 if every such doc carries the label its name earns, 1 otherwise
  (offenders printed to stderr).
PUB_FUN
lint__checks__shell__assignment_label__run() {
  lint__checks__shell__comments__audit "$__lint__checks__shell__assignment_label__DIR/assignment_label.awk" "$@"
}
