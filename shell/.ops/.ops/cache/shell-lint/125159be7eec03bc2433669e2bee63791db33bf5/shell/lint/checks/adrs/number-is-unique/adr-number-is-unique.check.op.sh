#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/adrs/number-is-unique/api.sh"

:<<'DOC'
The adr-number-is-unique check: one lint check plugin. See
shell/lint/registry.sh for what the roles mean.
DOC
@check.adr-number-is-unique() {
  @summary() {
    println "An ADR's number is unique: no record beside it, and none the default branch has added, carries the same one."
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
      "Give the flagged record the next number no record holds, here or on the" \
      "default branch, and update every citation of it to match."
  }

  @run() {
    lint__checks__adrs__number_is_unique__run "$@"
  }
}
