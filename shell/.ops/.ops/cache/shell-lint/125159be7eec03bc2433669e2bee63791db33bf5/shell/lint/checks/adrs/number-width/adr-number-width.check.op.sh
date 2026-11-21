#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/adrs/number-width/api.sh"

:<<'DOC'
The adr-number-width check: one lint check plugin. See
shell/lint/registry.sh for what the roles mean, and shell/lint/checks/adrs/form.sh
for the one-page form and how a repository asks for it.
DOC
@check.adr-number-width() {
  @summary() {
    println "A one-page ADR's number is padded to the same width as every other record's: six digits unless lint.json says otherwise."
  }

  @languages() {
    @arr __at_out markdown
    println "$__at_out"
  }

  @scopes() {
    @arr __at_out code
    println "$__at_out"
  }

  @hint() {
    printf '%s\n' \
      "Rename the record so its number carries zeros in front up to the width, as in" \
      "adrs/000007-fragments/adr.md. The title and every citation keep the plain number, ADR.7."
  }

  @run() {
    lint__checks__adrs__number_width__run "$@"
  }
}
