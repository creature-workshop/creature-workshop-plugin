#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/checks/shell/comments.sh"

: <<'MODULE'
The file-label check: a detector over the shell-scan scanner and the doc-block
model, run through the comment checks' shared audit.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__file_label__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/file-label"

: <<'PUB_FUN'
  Rejects a library file whose file doc is not labelled for its importers, a
  MODULE or FRAGMENT label on any block but a file doc, and an import of a
  FRAGMENT from outside its module. The label is what the lowering keys on to
  place the doc in the tree (ADR 000039), so a wrong one puts the file's doc on
  the wrong node; a fragment reached from another directory is the private
  reach ADR 000031 names.

  Only the files given are read, so an import from a file outside them is seen
  in the full sweep and not in a narrower run.

  Usage: lint__checks__shell__file_label__run <opts> <files...>

  <opts> is the run's options object; this check reads the library roots
  from its config, or the defaults.

  Returns 0 if every file doc carries its label and no fragment is reached from
  outside, 1 otherwise (offenders printed to stderr).
PUB_FUN
lint__checks__shell__file_label__run() {
  lint__checks__shell__comments__audit "$__lint__checks__shell__file_label__DIR/file_label.awk" "$@"
}
