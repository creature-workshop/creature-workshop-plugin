#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/adrs/page/api.sh"

:<<'DOC'
The adr-page check: one lint check plugin. See
shell/lint/registry.sh for what the roles mean, and shell/lint/checks/adrs/form.sh
for the one-page form and how a repository asks for it.
DOC
@check.adr-page() {
  @summary() {
    println "A one-page ADR's prose fits its page, counted from the Context heading to the end; fenced examples and figure lines are free."
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
      "Cut the record to one decision: the research, the alternatives at length and the plan" \
      "belong in the design document or ticket the header links, not on the page."
  }

  @run() {
    lint__checks__adrs__page__run "$@"
  }
}
