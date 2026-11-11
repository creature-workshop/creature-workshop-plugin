#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/shell/duplicate-file-doc/api.sh"

:<<'DOC'
The duplicate-file-doc check: one lint check plugin. See shell/lint/registry.sh
for what the roles mean.
DOC
@check.duplicate-file-doc() {
  @summary() {
    println "An entrypoint's usage is its file doc; it does not also carry a doc block above the code."
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
    println \
      "Delete the top-of-file doc block; the usage already is the file doc."
  }

  @run() {
    lint__checks__shell__duplicate_file_doc__run "$@"
  }
}
