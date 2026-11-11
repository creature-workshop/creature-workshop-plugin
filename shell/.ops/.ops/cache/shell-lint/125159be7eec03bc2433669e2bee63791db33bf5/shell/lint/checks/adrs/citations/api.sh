#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/checks/adrs/form.sh"

: <<'MODULE'
The adr-citations check: one part of the one-page form of a decision record, run
through the form's shared check over each record.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__adrs__citations__DIR="$SHELL_LINT_DIR/shell/lint/checks/adrs/citations"

: <<'PUB_FUN'
Prints a finding for each citation of a decision record, in a record among
<files...>, that is not a link whose text is ADR.<n>@<repository>.

  lint__checks__adrs__citations__run "$opts" adrs/000007-fragments/adr.md
    ->  adrs/000007-fragments/adr.md:22: link the citation: ADR.34@tool

Returns 0 when every citation is a link in that form, 1 otherwise.

Usage: lint__checks__adrs__citations__run <opts> <files...>
PUB_FUN
lint__checks__adrs__citations__run() {
  lint__checks__adrs__form__check "$__lint__checks__adrs__citations__DIR/adr_citations.awk" "$@"
}
