#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/structs/lint/api.sh"

:<<'DOC'
The let-in-subshell check: one lint check plugin. See lib/lint/registry.sh
for what the roles mean.
DOC
@check.let-in-subshell() {
  @summary() {
    println "@let and @unlet run as statements, never inside \$(...) or a pipe, where their bindings die with the subshell."
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
      "Call @let and @unlet as statements: they bind and release in the calling" \
      "shell, and a subshell keeps what they did to itself." \
      "Read the values you want back from one with @get, or bind first and use" \
      "the variables inside the substitution." \
      "If the subshell is the point, mark the line with '# structs-lint: allow'" \
      "and explain why."
  }

  @run() {
    __structs__lint__no_subshell_let "$@"
  }
}
