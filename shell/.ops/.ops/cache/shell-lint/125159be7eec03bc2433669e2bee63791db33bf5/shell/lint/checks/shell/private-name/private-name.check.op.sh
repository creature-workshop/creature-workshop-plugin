#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/shell/private-name/api.sh"

:<<'DOC'
The private-name check: one lint check plugin. See shell/lint/registry.sh for
what the roles mean.
DOC
@check.private-name() {
  @summary() {
    println "A private name in a library file is fully qualified: the module path, then for a variable its function."
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
      "Begin a function or a constant with the directories under lib/ or" \
      "interpreter/ joined by __; api.sh is the module, not a segment. Begin" \
      "a function's variable with __<module>__<function>__, the function's" \
      "own name without the module's spelling, and a plugin role's with" \
      "__<plugin>_<role>__. A caller outside the module uses the public name." \
      "Mark a line the rule does not fit with '# private-name-check: allow'" \
      "and say why."
  }

  @run() {
    lint__checks__shell__private_name__run "$@"
  }
}
