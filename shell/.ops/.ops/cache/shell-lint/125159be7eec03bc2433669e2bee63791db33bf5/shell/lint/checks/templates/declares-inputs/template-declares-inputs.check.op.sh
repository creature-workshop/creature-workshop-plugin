#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/templates/declares-inputs/api.sh"

:<<'DOC'
The template-declares-inputs lint check. shell/lint/registry.sh explains a
check's roles; shell/lint/checks/templates/api.sh explains the templates block in
lint.json.
DOC
@check.template-declares-inputs() {
  @summary() {
    println "Every CI component template starts with a spec.inputs block, even an empty one."
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
      "Add spec: with inputs: under it as the template's first document," \
      "before the ---. lint.json's templates.glob says which yaml files are" \
      "templates."
  }

  @run() {
    lint__checks__templates__declares_inputs__run "$@"
  }
}
