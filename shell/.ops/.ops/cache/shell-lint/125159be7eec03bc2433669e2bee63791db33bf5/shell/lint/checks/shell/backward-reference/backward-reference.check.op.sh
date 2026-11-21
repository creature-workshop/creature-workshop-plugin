#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/shell/backward-reference/api.sh"

:<<'DOC'
The backward-reference check: one lint check plugin. See shell/lint/registry.sh
for what the roles mean.
DOC
@check.backward-reference() {
  @summary() {
    println "Comment prose describes what the code does now, never what it used to do."
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
      "Rewrite the sentence in the present tense; the change itself belongs in" \
      "the commit message."
  }

  @run() {
    lint__checks__shell__backward_reference__run "$@"
  }
}
