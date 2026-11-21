#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/checks/adrs/form.sh"

: <<'MODULE'
The adr-number-width check: one part of the one-page form of a decision record, run
through the form's shared check over each record.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__adrs__number_width__DIR="$SHELL_LINT_DIR/shell/lint/checks/adrs/number-width"

: <<'PUB_FUN'
Prints a finding for each record among <files...> whose number is not padded
to the width <opts>.config gives, six digits by default.

  lint__checks__adrs__number_width__run "$opts" adrs/0007-fragments/adr.md
    ->  adrs/0007-fragments/adr.md:1: the record's number is written with 6 digits: 000007

Returns 0 when every record's number has the width, 1 otherwise.

Usage: lint__checks__adrs__number_width__run <opts> <files...>
PUB_FUN
lint__checks__adrs__number_width__run() {
  lint__checks__adrs__form__check "$__lint__checks__adrs__number_width__DIR/adr_number_width.awk" "$@"
}
