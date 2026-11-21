#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/structs/lint/api.sh"

:<<'DOC'
The enum-arms check: one lint check plugin. See lib/lint/registry.sh for
what the roles mean.
DOC
@check.enum-arms() {
  @summary() {
    println "A case whose arms are words a function in the file prints is an enum written by hand."
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
      "Declare the set once with @enum PREFIX MEMBER..., which binds a" \
      "constant per member, PREFIX_MEMBER, to its word; print and match" \
      "the constant, never the word:" \
      "  \"\$PREFIX_MEMBER\") ... ;;" \
      "A misspelt reference is then an unbound variable, not a silent" \
      "non-match. If the arm genuinely matches a word that is not a member" \
      "of a set, mark it with '# structs-lint: allow' and explain why."
  }

  @run() {
    __structs__lint__no_enum_arms "$@"
  }
}
