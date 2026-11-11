#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/awk/early-exit/api.sh"

:<<'DOC'
The awk-early-exit check: one lint check plugin. See shell/lint/registry.sh for
what the roles mean.
DOC
@check.awk-early-exit() {
  @summary() {
    println "An awk program reads its input to the end before it exits with an answer, so the writer on its pipe is never cut off."
  }

  @languages() {
    @arr __at_out awk
    println "$__at_out"
  }

  @scopes() {
    @arr __at_out code
    println "$__at_out"
  }

  @hint() {
    printf '%s\n' \
      "Record the answer in a variable, skip the remaining lines with a first" \
      "rule such as 'decided { next }', and exit from END. A reader that exits" \
      "early kills a writer still writing, and under pipefail the pipeline" \
      "fails with 141 now and then. An error exit, 'exit 3', is left alone. Mark" \
      "a program that never reads a pipe with '# early-exit-check: allow' and" \
      "say why."
  }

  @run() {
    lint__checks__awk__early_exit__run "$@"
  }
}
