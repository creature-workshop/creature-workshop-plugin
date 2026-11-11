#!/bin/sh

import "$SHELL_LINT_DIR/shell/lint/checks/adrs/form.sh"

: <<'MODULE'
The adr-page check: one part of the one-page form of a decision record, run
through the form's shared check over each record.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__adrs__page__DIR="$SHELL_LINT_DIR/shell/lint/checks/adrs/page"

: <<'PUB_FUN'
Prints a finding for each record among <files...> whose prose runs past the
page <opts>.config allows.

  lint__checks__adrs__page__run "$opts" adrs/000007-fragments/adr.md
    ->  adrs/000007-fragments/adr.md:1: 512 words of prose; a page is 450

Returns 0 when every record fits its page, 1 otherwise.

Usage: lint__checks__adrs__page__run <opts> <files...>
PUB_FUN
lint__checks__adrs__page__run() {
  lint__checks__adrs__form__check "$__lint__checks__adrs__page__DIR/adr_page.awk" "$@"
}
