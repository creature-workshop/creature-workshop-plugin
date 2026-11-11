#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/structs/lint/api.sh"

:<<'DOC'
The boolean-tests check: one lint check plugin. See lib/lint/registry.sh for
what the roles mean.
DOC
@check.boolean-tests() {
  @summary() {
    println "A struct boolean is asked with @is_true or @is_false, never tested against the literal true or false."
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
      "Ask @is_true \"\$value\" or @is_false \"\$value\" (or ! @is_true) instead of" \
      "[ \"\$value\" = true ]. The literal spells the backend's representation of a" \
      "boolean; the verbs survive swapping it, and only the struct spelling passes" \
      "them. A test that genuinely compares a string to the word true may be kept" \
      "by marking it with '# structs-lint: allow' and explaining why."
  }

  @run() {
    __structs__lint__no_boolean_tests "$@"
  }
}
