#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/log/check.sh"

:<<'DOC'
The println check: one lint check plugin. See shell-lint's shell/lint/registry.sh for
what the roles mean.
DOC
@check.println() {
  @summary() {
    println "A line printed with one argument is println, not printf '%s\\n'."
  }

  @languages() {
    @arr __check_println__out shell
    println "$__check_println__out"
  }

  @scopes() {
    @arr __check_println__out code
    println "$__check_println__out"
  }

  @hint() {
    println \
      "Call println with the value. It prints each argument as its own line." \
      "A printf of several arguments is a different call and stays." \
      "A call the verb cannot replace keeps '# println-check: allow' on the" \
      "line, or within the three lines above it, saying why."
  }

  @run() {
    log__check__no_single_printf "$@"
  }
}
