#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/structs/lint/_jq_program.sh"

:<<'DOC'
The jq-program check: one lint check plugin. See shell-lint's
shell/lint/registry.sh for what the roles mean.
DOC
@check.jq-program() {
  @summary() {
    println "No jq programs: neither a .jq file nor a call of @jq. The structs verbs read and build a structured value."
  }

  @languages() {
    @arr __at_out shell jq
    println "$__at_out"
  }

  @scopes() {
    @arr __at_out code tests
    println "$__at_out"
  }

  @hint() {
    printf '%s\n' \
      "Read and build the value in shell with the structs verbs (@get, @set," \
      "@map, @filter, @reduce, @entries, ...), in place of the .jq file and" \
      "the @jq call that runs it. If a .jq file has to exist, put" \
      "'# jq-program-check: allow' in a comment line of its own and say why." \
      "If a call has to stay, put the same marker on its line or within the" \
      "three lines above it. A file under lib/structs may call @jq."
  }

  @run() {
    __structs__lint__jq_program__run "$@"
  }
}
