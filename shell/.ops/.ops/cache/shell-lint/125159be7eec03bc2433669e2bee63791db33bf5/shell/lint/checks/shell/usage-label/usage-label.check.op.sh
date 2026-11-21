#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/shell/usage-label/api.sh"

:<<'DOC'
The usage-label check: one lint check plugin. See shell/lint/registry.sh for
what the roles mean.
DOC
@check.usage-label() {
  @summary() {
    println "An entrypoint's usage heredoc opens on HELP, and HELP names nothing else."
  }

  @languages() {
    @arr __at_out shell
    println "$__at_out"
  }

  @scopes() {
    @arr __at_out code
    println "$__at_out"
  }

  @hint() {
    printf '%s\n' \
      "Open the heredoc assigned to USAGE on the terminator HELP, and give any" \
      "other heredoc a different one."
  }

  @run() {
    lint__checks__shell__usage_label__run "$@"
  }
}
