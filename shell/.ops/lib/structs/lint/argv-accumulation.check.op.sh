#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/structs/lint/api.sh"

:<<'DOC'
The argv-accumulation check: one lint check plugin. See lib/lint/registry.sh
for what the roles mean.
DOC
@check.argv-accumulation() {
  @summary() {
    println "An argument list is a struct array run through @apply, never grown by hand with set -- \"\$@\"."
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
      "Collect the arguments in a struct array (@arr, then @push for each one" \
      "that applies) and run the command with @apply <command> [fixed...] \"\$array\"." \
      "Growing the positionals by hand hides the list from every other verb and" \
      "reads inside out. Where the positionals genuinely must be rebuilt in place," \
      "mark the line with '# structs-lint: allow' and explain why."
  }

  @run() {
    __structs__lint__no_argv_accumulation "$@"
  }
}
