#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/shell/private-file/api.sh"

:<<'DOC'
The private-file check: one lint check plugin. See shell/lint/registry.sh for
what the roles mean.
DOC
@check.private-file() {
  @summary() {
    println "A private file's name begins with _."
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
      "A library file imported only from its own directory is private to its" \
      "module, and its name begins with _. A file imported from elsewhere is" \
      "the module's public surface. Mark a file the rule does not fit with" \
      "'# private-file-check: allow' and say why."
  }

  @run() {
    lint__checks__shell__private_file__run "$@"
  }
}
