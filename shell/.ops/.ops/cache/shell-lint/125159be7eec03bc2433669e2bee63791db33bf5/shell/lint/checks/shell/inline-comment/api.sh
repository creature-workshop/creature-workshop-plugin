#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/checks/shell/comments.sh"

: <<'MODULE'
The inline-comment check: a detector over the shell-scan scanner and the doc-block
model, run through the comment checks' shared audit.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__inline_comment__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/inline-comment"

: <<'PUB_FUN'
  Rejects a # comment addressed to a reader anywhere but above a module-root
  constant or variable, and one there that does not lead with the label its
  name earns (ADR 000040). Inside a function body a comment is a finding: what
  it says belongs in the function's doc, or the function splits. A line a tool
  reads, a shellcheck directive or a check's allow marker, is never one.

  Usage: lint__checks__shell__inline_comment__run <opts> <files...>

  <opts> is the run's options object; this check reads the library roots
  from its config, or the defaults.

  Returns 0 if every reader-facing comment sits where it may and leads as it
  must, 1 otherwise (offenders printed to stderr).
PUB_FUN
lint__checks__shell__inline_comment__run() {
  lint__checks__shell__comments__audit "$__lint__checks__shell__inline_comment__DIR/inline_comment.awk" "$@"
}
