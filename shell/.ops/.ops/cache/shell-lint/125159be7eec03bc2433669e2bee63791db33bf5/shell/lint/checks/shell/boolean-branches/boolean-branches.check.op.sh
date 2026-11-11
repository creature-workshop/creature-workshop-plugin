#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/shell/boolean-branches/api.sh"

:<<'DOC'
The boolean-branches check: one lint check plugin. See shell/lint/registry.sh
for what the roles mean.
DOC
@check.boolean-branches() {
  @summary() {
    println "A predicate is @succeeds <condition>, never an if whose branches are @true and @false."
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
      "Write @succeeds <condition> (or @fails <condition>) in place of an if" \
      "whose then-body is @true and whose else-body is @false, or the other way" \
      "round. It runs the condition and prints the struct boolean for its exit" \
      "status, so the predicate is one line and reads as what it tests. A guard" \
      "that prints one constructor and returns is a different shape and passes," \
      "and so does an if whose condition joins commands with && or ||." \
      "An if that has to stay may be kept by marking it with" \
      "'# structs-lint: allow' and explaining why."
  }

  @run() {
    lint__checks__shell__boolean_branches__run "$@"
  }
}
