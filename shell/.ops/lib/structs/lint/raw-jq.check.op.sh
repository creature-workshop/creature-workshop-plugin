#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/structs/lint/api.sh"

:<<'DOC'
The raw-jq check: one lint check plugin. See lib/lint/registry.sh for what
the roles mean.
DOC
@check.raw-jq() {
  @summary() {
    println "No raw jq or opx outside the structs API; the @-sigil verbs are the surface."
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
      "Use the @-sigil verbs (@get, @set, @map, ...). If a call genuinely" \
      "cannot be expressed via the API, mark it with '# structs-lint: allow'" \
      "and explain why."
  }

  @run() {
    __structs__lint__no_raw_jq "$@"
  }
}
