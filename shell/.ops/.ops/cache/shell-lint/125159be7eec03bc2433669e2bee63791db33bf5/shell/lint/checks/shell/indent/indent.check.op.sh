#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/shell/indent/api.sh"

:<<'DOC'
The indent check: one lint check plugin. See shell/lint/registry.sh for what
the roles mean. Bats files are shell, so tests are in scope.
DOC
@check.indent() {
  @summary() {
    println "Leading whitespace is a multiple of the configured width, tabs only when allowed, and no line ends in whitespace; heredoc bodies are exempt."
  }

  @languages() {
    @arr __check_indent__out shell
    println "$__check_indent__out"
  }

  @scopes() {
    @arr __check_indent__out code tests
    println "$__check_indent__out"
  }

  @hint() {
    printf '%s\n' \
      "Reindent the flagged lines to the configured width, drop trailing" \
      "whitespace, and use tabs only where lint.json allows them; heredoc bodies" \
      "are exempt."
  }

  @run() {
    lint__checks__shell__indent__run "$@"
  }
}
