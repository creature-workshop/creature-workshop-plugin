#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/shell/function-label/api.sh"

:<<'DOC'
The function-label check: one lint check plugin. See shell/lint/registry.sh for
what the roles mean.
DOC
@check.function-label() {
  @summary() {
    println "A function's doc opens on PUB_FUN when the function is a library module's public surface and FUN otherwise, agreeing with the name."
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
      "Open the doc above a library function on PUB_FUN unless its name has the" \
      "leading __ of a private function or the @ of a plugin's role; open every" \
      "other function's doc, an entrypoint's included, on FUN. A label that" \
      "disagrees with the name is fixed by renaming, on its own commit."
  }

  @run() {
    lint__checks__shell__function_label__run "$@"
  }
}
