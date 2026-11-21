#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/checks/adrs/form.sh"

: <<'MODULE'
The adr-status check: one part of the one-page form of a decision record, run
through the form's shared check over each record.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__adrs__status__DIR="$SHELL_LINT_DIR/shell/lint/checks/adrs/status"

: <<'PUB_FUN'
Prints a finding for each record among <files...> whose Status line says
anything but approved, or superseded by a linked record. A record is merged by
being approved, so one that says proposed is wrong the moment it lands.

  lint__checks__adrs__status__run "$opts" adrs/000007-fragments/adr.md
    ->  adrs/000007-fragments/adr.md:3: the status is "approved", or "superseded by" and a link to the ADR that did

Returns 0 when every record's status stands, 1 otherwise.

Usage: lint__checks__adrs__status__run <opts> <files...>
PUB_FUN
lint__checks__adrs__status__run() {
  lint__checks__adrs__form__check "$__lint__checks__adrs__status__DIR/adr_status.awk" "$@"
}
