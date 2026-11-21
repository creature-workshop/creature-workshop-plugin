#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/shell/public-name/api.sh"

:<<'DOC'
The public-name check: one lint check plugin. See shell/lint/registry.sh for
what the roles mean.
DOC
@check.public-name() {
  @summary() {
    println "A public name in a library file begins with that file's module path."
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
      "Begin the name with the directories under lib/ or interpreter/ joined by" \
      "__; api.sh is the module, not a segment. A name that begins with __ is" \
      "private, and one that begins with @ is a role. Mark a line the rule does" \
      "not fit with '# public-name-check: allow' and say why."
  }

  @run() {
    lint__checks__shell__public_name__run "$@"
  }
}
