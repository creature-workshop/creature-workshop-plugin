#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/checks/shell/comments.sh"

: <<'MODULE'
The duplicate-file-doc check: a detector over the shell-scan scanner and the doc-block
model, run through the comment checks' shared audit.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__shell__duplicate_file_doc__DIR="$SHELL_LINT_DIR/shell/lint/checks/shell/duplicate-file-doc"

: <<'PUB_FUN'
  Rejects an entrypoint that documents itself twice: a doc block above the code
  as well as the usage its --help prints. The usage is the file doc -- the same
  subject, addressed to the reader who asked for it -- so the second copy has no
  audience of its own and only drifts from the first.

  Every file is a candidate; carrying a usage is what makes one an entrypoint,
  so a file without one has nothing to duplicate and passes on that account.

  Delete the top-of-file block. The usage already is the file doc; nothing in
  the second copy is needed once that is so.

  Usage: lint__checks__shell__duplicate_file_doc__run <opts> <files...>

  <opts> is the run's options object; this check reads nothing from it.

  Returns 0 if no entrypoint carries both, 1 otherwise (offenders printed to
  stderr).
PUB_FUN
lint__checks__shell__duplicate_file_doc__run() {
  lint__checks__shell__comments__audit "$__lint__checks__shell__duplicate_file_doc__DIR/duplicate_file_doc.awk" "$@"
}
