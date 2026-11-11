#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/adrs/shape/api.sh"

:<<'DOC'
The adr-shape check: one lint check plugin. See
shell/lint/registry.sh for what the roles mean, and shell/lint/checks/adrs/form.sh
for the one-page form and how a repository asks for it.
DOC
@check.adr-shape() {
  @summary() {
    println "A one-page ADR opens on the title carrying its own number, has Status, Date and Merge request header lines, and the sections Context, Decision, Consequences in that order."
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
      "Start from the repository's ADR template: the title is \"# ADR.<n>: <the decision>\" with" \
      "the record's number and no leading zeros, then the header lines, then the three sections."
  }

  @run() {
    lint__checks__adrs__shape__run "$@"
  }
}
