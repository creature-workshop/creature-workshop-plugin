#!/usr/bin/env bash

import "$SHELL_LINT_DIR/shell/lint/checks/templates/job-lands-once/api.sh"

:<<'DOC'
The job-lands-once lint check. shell/lint/registry.sh explains a check's
roles; shell/lint/checks/templates/api.sh explains the templates block in lint.json.
DOC
@check.job-lands-once() {
  @summary() {
    println "A template's job runs once per merge request, in the landing run: every rule that matches a merge-request pipeline also requires the landing mark."
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
      "Add the landing mark from lint.json's templates.mark to each if: that" \
      "matches merge_request_event. If the job must run on every push (a" \
      "governance check, a preview), list its template under" \
      "templates.every_push instead."
  }

  @run() {
    lint__checks__templates__job_lands_once__run "$@"
  }
}
