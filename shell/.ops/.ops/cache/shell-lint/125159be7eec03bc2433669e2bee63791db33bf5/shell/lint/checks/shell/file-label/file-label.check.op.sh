#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/shell/file-label/api.sh"

:<<'DOC'
The file-label check: one lint check plugin. See shell/lint/registry.sh for
what the roles mean.
DOC
@check.file-label() {
  @summary() {
    println "A library file's doc opens on MODULE when consumers import it and FRAGMENT when only its module does, and a fragment is imported by its module alone."
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
      "Open the file doc on MODULE when a file outside its directory imports it," \
      "FRAGMENT otherwise; use neither label on any other block. Import a" \
      "fragment only from its own directory, or make it a MODULE."
  }

  @run() {
    lint__checks__shell__file_label__run "$@"
  }
}
