#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/structs/lint/api.sh"

:<<'DOC'
The string-tests check: one lint check plugin. See lib/lint/registry.sh for
what the roles mean.
DOC
@check.string-tests() {
  @summary() {
    println "A printed answer is asked with @defined, never tested with -z or -n."
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
      "Ask @defined \"\$value\" (or ! @defined) instead." \
      "@get answers the string null for a missing key, and -z / -n read null" \
      "as present; @defined is false for both null and the empty string." \
      "If the test genuinely wants the string's length, mark it with" \
      "'# structs-lint: allow' and explain why."
  }

  @run() {
    __structs__lint__no_string_tests "$@"
  }
}
