#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/.scripts/_shellops_repositories.sh" \
  "$SHELLOPS_DIR/lib/pipelines/api.sh"

# file-label-check: allow -- a helper under .scripts is keyed outside any library root and would read as an entrypoint
: <<'FRAGMENT'
What shellops' certifications check: the pipelines of some of its copies on
the candidate. A certification names the copies, _shellops_repositories.sh
says what they are, and lib/pipelines/api.sh puts the candidate where each
forge runs it and reports the verdicts. Each verdict is the certification's,
named for the copy.
FRAGMENT

: <<'FUN'
Prints the verdicts of the pipelines the copies <names>, names from
_shellops_repositories.sh, ran on <sha>, as a certification's @certify
prints them: {check, state, url}, check being the copy's name. Non-zero
when the list has no copy of a name or a copy refused the candidate.

  __pipelines_certification__verdicts '["origin", "mirror"]' abc123  ->  [{"check": "mirror", "state": "success", "url": "https://..."}]

Usage: __pipelines_certification__verdicts <names> <sha>
FUN
__pipelines_certification__verdicts() {
  __pipelines_certification__verdicts__repositories="$(__shellops_repositories__named "$1")" || return 1
  __pipelines_certification__verdicts__pipelines="$(pipelines__verdicts "$__pipelines_certification__verdicts__repositories" "$2")" || return 1

  @map __pipelines_certification__verdicts__out __pipelines_certification__verdict "$__pipelines_certification__verdicts__pipelines"
  println "$__pipelines_certification__verdicts__out"
}

: <<'FUN'
@map callback: the wrapped pipeline verdict <verdict>, {repository, forge,
state, url}, as the certification's, {check, state, url}.
FUN
__pipelines_certification__verdict() {
  @get __pipelines_certification__verdict__get_1 "$1" '.repository' ''
  @get __pipelines_certification__verdict__get_2 "$1" '.state' ''
  @get __pipelines_certification__verdict__get_3 "$1" '.url' ''
  @obj __pipelines_certification__verdict__out \
    '.check' "$__pipelines_certification__verdict__get_1" \
    '.state' "$__pipelines_certification__verdict__get_2" \
    '.url'   "$__pipelines_certification__verdict__get_3"
  println "$__pipelines_certification__verdict__out"
}
