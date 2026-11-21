#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/shell/assignment-label/api.sh"

:<<'DOC'
The assignment-label check: one lint check plugin. See shell/lint/registry.sh
for what the roles mean.
DOC
@check.assignment-label() {
  @summary() {
    println "A doc above a module-root variable opens on VAR and above a constant on CONST, with PUB_ when a library file's name has no leading __, agreeing with the name; each root assignment carries its own doc."
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
      "Open the doc above a root assignment on CONST when the name's last __" \
      "segment is upper case and VAR otherwise; prefix PUB_ in a library file" \
      "when the name has no leading __. A label that disagrees with the name" \
      "is fixed by renaming, on its own commit. Give each assignment its own" \
      "doc: one right below a documented one shares nothing with it."
  }

  @run() {
    lint__checks__shell__assignment_label__run "$@"
  }
}
