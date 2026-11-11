#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/structs/lint/api.sh"

:<<'DOC'
The let-pairing check: one lint check plugin. See lib/lint/registry.sh for
what the roles mean.
DOC
@check.let-pairing() {
  @summary() {
    println "Every @let in a function has an @unlet before its closing brace naming the same prefix and keys, and the prefix is the function's own."
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
      "Release every binding on the function's last line with an @unlet naming" \
      "the @let's prefix and the same keys; the finding spells the line to add." \
      "Bind under the function's own prefix, __<name>__, so no two functions" \
      "shadow each other's bindings." \
      "If a binding genuinely outlives its function, mark the @let with" \
      "'# structs-lint: allow' and explain why."
  }

  @run() {
    __structs__lint__let_pairs "$@"
  }
}
