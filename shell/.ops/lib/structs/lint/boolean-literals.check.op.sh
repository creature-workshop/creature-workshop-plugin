#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/structs/lint/api.sh"

:<<'DOC'
The boolean-literals check: one lint check plugin. See lib/lint/registry.sh
for what the roles mean.
DOC
@check.boolean-literals() {
  @summary() {
    println "A boolean answer is @true, @false or @succeeds, never a printed true or false."
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
      "Spell a literal answer with the constructors: @true or @false." \
      "An if/else that exists to print one is @succeeds <condition>: it runs" \
      "the condition and prints true or false for its exit status." \
      "Writing true out spells the backend's representation of a boolean; the" \
      "constructors survive swapping it. If a printed true or false genuinely" \
      "is not a struct boolean, mark it with '# structs-lint: allow' and" \
      "explain why."
  }

  @run() {
    __structs__lint__no_boolean_literals "$@"
  }
}
