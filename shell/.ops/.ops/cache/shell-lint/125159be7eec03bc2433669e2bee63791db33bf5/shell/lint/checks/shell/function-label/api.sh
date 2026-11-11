#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/checks/shell/comments.sh"

: <<'MODULE'
The function-label check: a detector over the shell-scan scanner and the doc-block
model, run through the comment checks' shared audit.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__function_label__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/function-label"

: <<'PUB_FUN'
  Rejects a function doc whose label does not say what the function is to its
  callers: PUB_FUN for a library module's public surface, FUN for a private
  function, a plugin's role, or any function of an entrypoint. The label is
  what the lowering reads for the function's visibility (ADR 000039), so it
  has to agree with the name ADR 000031 gives the function, and a PUB_FUN or
  FUN on a block that documents no function is a finding too.

  Usage: lint__checks__shell__function_label__run <opts> <files...>

  <opts> is the run's options object; this check reads the library roots
  from its config, or the defaults.

  Returns 0 if every function doc carries the label its name earns, 1
  otherwise (offenders printed to stderr).
PUB_FUN
lint__checks__shell__function_label__run() {
  lint__checks__shell__comments__audit "$__lint__checks__shell__function_label__DIR/function_label.awk" "$@"
}
