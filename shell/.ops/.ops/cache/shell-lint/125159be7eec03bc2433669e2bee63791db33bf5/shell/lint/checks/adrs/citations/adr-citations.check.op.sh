#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/adrs/citations/api.sh"

:<<'DOC'
The adr-citations check: one lint check plugin. See
shell/lint/registry.sh for what the roles mean, and shell/lint/checks/adrs/form.sh
for the one-page form and how a repository asks for it.
DOC
@check.adr-citations() {
  @summary() {
    println "A one-page ADR cites another decision record as a link whose text is ADR.<n>@<repository>."
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
      "Write the citation as [ADR.<n>@<repository>](<where the record is>), with no leading" \
      "zeros; a citation inside a fenced example is left alone."
  }

  @run() {
    lint__checks__adrs__citations__run "$@"
  }
}
