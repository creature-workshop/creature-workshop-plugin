#!/bin/sh

import \
  "$SHELL_LINT_DIR/shell/lint/checks/templates/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
The job-lands-once check: one rule over a catalog's CI component templates, run
over the templates the shared templates module selects.
MODULE

# CONST: This check's directory, absolute so the caller's cwd does not matter.
__lint__checks__templates__job_lands_once__DIR="$SHELL_LINT_DIR/shell/lint/checks/templates/job-lands-once"

: <<'PUB_FUN'
Reports each job in <files...> with a rule that matches a merge-request
pipeline without requiring the landing mark. Templates lint.json lists
under every_push are exempt; files that are not templates are skipped. When
lint.json names no mark, the check does nothing and returns 0.

  lint__checks__templates__job_lands_once__run "$opts" templates/rust--test/template.yml
    ->  templates/rust--test/template.yml:38: job '$[[ inputs.job-name ]]' runs on every push: its rule matches merge_request_event without the mark 'scheduler\/next-merge'

Returns 0 when every job lands once, 1 otherwise.

Usage: lint__checks__templates__job_lands_once__run <opts> <files...>
PUB_FUN
lint__checks__templates__job_lands_once__run() {
  lint__checks__templates__job_lands_once__run__mark="$(lint__checks__templates__mark "$1")"
  @defined "$lint__checks__templates__job_lands_once__run__mark" || return 0

  lint__checks__templates__job_lands_once__run__exempt="$(lint__checks__templates__every_push "$1")"
  lint__checks__templates__job_lands_once__run__files="$(lint__checks__templates__select "$@")"
  lint__checks__templates__job_lands_once__run__held="$(lint__checks__templates__without \
    "$lint__checks__templates__job_lands_once__run__files" \
    "$lint__checks__templates__job_lands_once__run__exempt"
  )"
  CI_TEMPLATE_MARK="$lint__checks__templates__job_lands_once__run__mark" \
    lint__checks__templates__report "$__lint__checks__templates__job_lands_once__DIR/job_lands_once.awk" "$lint__checks__templates__job_lands_once__run__held"
}
