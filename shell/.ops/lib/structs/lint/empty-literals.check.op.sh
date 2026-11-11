#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/structs/lint/api.sh"

:<<'DOC'
The empty-literals check: one lint check plugin. See lib/lint/registry.sh
for what the roles mean.
DOC
@check.empty-literals() {
  @summary() {
    println "Empty arrays and objects are built with @arr and @obj, never written out as literals."
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
      "Build them with the constructors: @arr for an array, @obj for an object." \
      "Writing one out spells the backend's representation, so it only stays" \
      "correct for as long as jq stays the backend; the constructors survive" \
      "swapping it. If a literal genuinely cannot be replaced, mark it with" \
      "'# structs-lint: allow' and explain why."
  }

  @run() {
    __structs__lint__no_empty_literals "$@"
  }
}
