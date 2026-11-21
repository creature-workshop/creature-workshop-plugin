#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/git/forge.sh" \
  "$SHELLOPS_DIR/lib/sites/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Pipelines: what a forge runs on a commit, asked across the repositories a
commit is put at. A pipeline is not a certification: a merge request's
pipeline runs with none in sight, and a certification composes the
verdicts the pipelines give. The commit is put at the candidate branch of
each repository with a host, in order, as a branch site
(lib/git/branch.site.op.sh); then the pipeline each repository ran on it is
waited for and recorded through `action forge report-run`, so the pipelines
proceed together and every push lands before any is waited for. The
repository this run is on (lib/git/forge.sh) runs the commit as it
runs any merge, its pipeline being this run, so it is neither pushed to nor
waited for; a mirrored one runs what arrives and is waited for; one on no
forge has nothing to run it, so it is neither pushed to nor waited for, and
the log says so.
MODULE

# CONST: The verdict recorded for a repository whose pipeline could not be waited for.
__pipelines__UNANSWERED="unanswered"

: <<'PUB_FUN'
Puts <sha> where each of <repositories>, a struct array of {name,
repository}, runs it, in order, then prints the verdict of each one's
pipeline on it: a struct array of {repository, forge, state, url}. Non-zero
when a repository refuses the commit.

Usage: pipelines__verdicts <repositories> <sha>
PUB_FUN
pipelines__verdicts() {
  __pipelines__stage_all "$1" "$2" || return 1
  __pipelines__verdicts "$1" "$2"
}

: <<'FUN'
Puts <sha> at the candidate branch of each of <repositories>, in order. A
repository that refuses it stops the ones after it. Non-zero when any
refused.

Usage: __pipelines__stage_all <repositories> <sha>
FUN
__pipelines__stage_all() {
  @any __pipelines__stage_all__refused __pipelines__stage_refused "$1" "$2"

  @is_false "$__pipelines__stage_all__refused"
}

: <<'FUN'
True when putting <sha> at the wrapped <repository>'s candidate branch was
refused, false when it went through: __pipelines__stage the
other way up, so a walk over the repositories stops at the first refusal.

  $1 {name, repository}   $2 sha
FUN
__pipelines__stage_refused() {
  @get __pipelines__stage_refused__get_1 "$1" '.name'
  @get __pipelines__stage_refused__get_2 "$1" '.repository'
  ! __pipelines__stage "$__pipelines__stage_refused__get_1" "$__pipelines__stage_refused__get_2" "$2"
}

: <<'FUN'
Puts <sha> at the candidate branch of the repository <repository>, named
<name>, as a branch site. A repository on no forge is left alone, nothing
there running a candidate. So is one without a host: the forge this run is
on runs the candidate as it runs any merge, and a mirror runs what arrives.
Non-zero when the clone cannot be readied or the branch cannot move.

Usage: __pipelines__stage <name> <repository> <sha>
FUN
__pipelines__stage() {
  if ! @is_true "$(git__forge__named "$2")"; then
    log "Nothing to stage at ${1}: it lives on no forge, so nothing runs the candidate there."
    return 0
  fi

  if ! @is_true "$(git__forge__hosted "$2")"; then
    log "Nothing to stage at ${1}: no host there; its forge runs the candidate as it runs any merge."
    return 0
  fi

  __pipelines__stage__branch="$(git__forge__candidate_branch "$2")"
  @get __pipelines__stage__get_3 "$2" '.remote' ''
  log "Pushing ${3} to ${__pipelines__stage__branch} on $(git__forge__name "$2") ($__pipelines__stage__get_3), for ${1}."
  @obj __pipelines__stage__obj_4 '.kind' branch '.branch' "$__pipelines__stage__branch" '.repository' "$2"
  @obj __pipelines__stage__obj_5 '.commit' "$3"
  sites__put "$1" "$__pipelines__stage__obj_4" "$__pipelines__stage__obj_5"
}

: <<'FUN'
Prints the verdicts of <repositories> on <sha>: one per repository on a
forge other than the one this run is on, as {repository, forge, state,
url}, each repository's pipeline waited for and recorded on the commit at
the forge this clone came from. One whose pipeline could not be waited for
answers unanswered; the one this run is on answers nothing, its pipeline
being this run, and one on no forge answers nothing, having no pipeline.

Usage: __pipelines__verdicts <repositories> <sha>
FUN
__pipelines__verdicts() {
  @arr __pipelines__verdicts__arr_6
  @reduce __pipelines__verdicts__out __pipelines__collect_verdict "$1" "$__pipelines__verdicts__arr_6" "$2"
  println "$__pipelines__verdicts__out"
}

: <<'FUN'
@reduce callback: <acc> with the verdict of the wrapped <repository>'s
pipeline on <sha> appended, unless the repository is the one this run is on
or lives on no forge.

  $1 acc   $2 {name, repository}   $3 sha
FUN
__pipelines__collect_verdict() {
  @get __pipelines__collect_verdict__name "$2" '.name'
  @get __pipelines__collect_verdict__repository "$2" '.repository'

  if ! @is_true "$(git__forge__named "$__pipelines__collect_verdict__repository")"; then
    log "No pipeline to wait for at ${__pipelines__collect_verdict__name}: it lives on no forge."
    println "$1"
    return 0
  fi

  if @is_true "$(git__forge__is_this_run "$__pipelines__collect_verdict__repository")"; then
    println "$1"
    return 0
  fi

  __pipelines__collect_verdict__state="$__pipelines__UNANSWERED"
  __pipelines__collect_verdict__url=""
  if __pipelines__collect_verdict__outcome="$(__pipelines__report "$__pipelines__collect_verdict__name" "$__pipelines__collect_verdict__repository" "$3")"; then
    @get __pipelines__collect_verdict__state "$__pipelines__collect_verdict__outcome" '.state' "$__pipelines__UNANSWERED"
    @get __pipelines__collect_verdict__url "$__pipelines__collect_verdict__outcome" '.url' ''
  fi

  @obj __pipelines__collect_verdict__obj_7 \
    '.repository' "$__pipelines__collect_verdict__name" \
    '.forge'      "$(git__forge__name "$__pipelines__collect_verdict__repository")" \
    '.state'      "$__pipelines__collect_verdict__state" \
    '.url'        "$__pipelines__collect_verdict__url"
  @push __pipelines__collect_verdict__out "$1" "$__pipelines__collect_verdict__obj_7"
  println "$__pipelines__collect_verdict__out"
}

: <<'FUN'
Waits for the pipeline <repository>'s forge ran on <sha> and records it on
the commit at the forge this clone came from, through `action forge
report-run`, under <name>; prints the outcome it answers with ({state,
url}). Non-zero when the wait itself failed.

Usage: __pipelines__report <name> <repository> <sha>
FUN
__pipelines__report() {
  @let "$2" __pipelines__report__ forge owner repo host token_env

  "$SHELLOPS_DIR/action" forge report-run \
    --site "$1" \
    --forge "$__pipelines__report__forge" \
    --sha "$3" \
    --owner "$__pipelines__report__owner" \
    --repo "$__pipelines__report__repo" \
    --host "$__pipelines__report__host" \
    --token-env "$__pipelines__report__token_env"
  __pipelines__report__status=$?

  @unlet __pipelines__report__ forge owner repo host token_env
  return "$__pipelines__report__status"
}
