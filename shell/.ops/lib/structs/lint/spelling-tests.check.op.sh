#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/structs/lint/api.sh"

:<<'DOC'
The spelling-tests check: one lint check plugin. See lib/lint/registry.sh
for what the roles mean.
DOC
@check.spelling-tests() {
  @summary() {
    println "A value held to a spelling by hand, a case pattern with a character class or an anchored grep, is a type written by hand."
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
      "Declare the type once as a plugin, <name>.type.op.sh defining" \
      "@type.<name>() with <name>_is and <name>_from (lib/structs/type.sh" \
      "says what the roles mean), load it with @load_type, and ask" \
      "@is_<name> or construct with @<name>. A struct scalar already has" \
      "one: @is_int, @is_number, @is_bool, @is_string. If the pattern" \
      "genuinely holds no type's spelling, mark it with" \
      "'# structs-lint: allow' and explain why."
  }

  @run() {
    structs__lint__no_spelling_tests "$@"
  }
}
