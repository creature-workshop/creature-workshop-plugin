#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/templates/inherits-bootstrap/api.sh"

:<<'DOC'
The template-inherits-bootstrap lint check. shell/lint/registry.sh explains a
check's roles; shell/lint/checks/templates/api.sh explains the templates block in
lint.json.
DOC
@check.template-inherits-bootstrap() {
  @summary() {
    println "Only the base template defines before_script; every other job inherits it by extending the base job."
  }

  @languages() {
    @arr __at_out yaml
    println "$__at_out"
  }

  @scopes() {
    @arr __at_out code
    println "$__at_out"
  }

  @hint() {
    printf '%s\n' \
      "Remove the job's before_script and extend the base job instead." \
      "lint.json's templates.base names the base template."
  }

  @run() {
    lint__checks__templates__inherits_bootstrap__run "$@"
  }
}
