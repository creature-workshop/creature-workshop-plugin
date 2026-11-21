#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/adrs/status/api.sh"

:<<'DOC'
The adr-status check: one lint check plugin. See
shell/lint/registry.sh for what the roles mean, and shell/lint/checks/adrs/form.sh
for the one-page form and how a repository asks for it.
DOC
@check.adr-status() {
  @summary() {
    println "A one-page ADR's status is approved, or names the ADR that superseded it; a record is never merged as proposed."
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
      "Write \"- Status: approved\" from the first draft: the merge that lands the record is its" \
      "approval, and a record that is not approved never reaches the default branch."
  }

  @run() {
    lint__checks__adrs__status__run "$@"
  }
}
