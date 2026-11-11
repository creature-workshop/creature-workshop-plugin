#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/checks/adrs/form.sh"

: <<'MODULE'
The adr-shape check: one part of the one-page form of a decision record, run
through the form's shared check over each record.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__adrs__shape__DIR="$SHELL_LINT_DIR/shell/lint/checks/adrs/shape"

: <<'PUB_FUN'
Prints a finding for each part of the one-page shape a record among
<files...> is missing: the title carrying its number, the header lines, the
three sections in order.

  lint__checks__adrs__shape__run "$opts" adrs/000007-fragments/adr.md
    ->  adrs/000007-fragments/adr.md:1: the header has no "- Date:" line

Returns 0 when every record has the shape, 1 otherwise.

Usage: lint__checks__adrs__shape__run <opts> <files...>
PUB_FUN
lint__checks__adrs__shape__run() {
  lint__checks__adrs__form__check "$__lint__checks__adrs__shape__DIR/adr_shape.awk" "$@"
}
