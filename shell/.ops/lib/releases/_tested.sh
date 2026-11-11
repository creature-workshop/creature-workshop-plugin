#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/forge/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/git/remotes.sh"

: <<'MODULE'
Check C, tested is merged (ADR.3@global): a landing at the trunk's tip is
the merge of one merge request, and the tree it left on the trunk is the
tree that merge request's landing run validated. The forge says which merge
request landed the commit and how the run on its head stands; the clone
compares the trees, fetching the head off the forge when the merge did not
bring it along, as a squashed one does not. A landing the check refuses
carries the reason on its merge request, and earns no tag.
MODULE

: <<'PUB_FUN'
Passes quietly when the commit <ref> names is a landing whose tree is the
one its landing run validated, and fails naming the reason otherwise, the
reason posted on the merge request where there is one: no merge request
landed the commit, the run on the merged head did not pass, or the trunk's
tree is not the tested tree. Fails too when the forge cannot be asked or
the merged head cannot be reached.

Usage: releases__tested__assert HEAD
PUB_FUN
releases__tested__assert() {
  __releases__tested__assert__sha="$(git__commit_of "$1")" || return 1
  __releases__tested__assert__token="$(forge__require_token)" || return 1
  @obj __releases__tested__assert__obj_1 '.sha' "$__releases__tested__assert__sha" '.token' "$__releases__tested__assert__token"
  __releases__tested__assert__landing="$(forge__landing_at "$__releases__tested__assert__obj_1")" || return 1

  if @null __releases__tested__assert__null_2; [ "$__releases__tested__assert__landing" = "$__releases__tested__assert__null_2" ]; then
    error "check C: no merge request landed ${__releases__tested__assert__sha} on the trunk; a commit reaches the trunk through an approved merge request alone (ADR.3@global)."
    return 1
  fi

  __releases__tested__assert__reason="$(releases__tested__reason "$__releases__tested__assert__sha" "$__releases__tested__assert__landing")" || return 1
  if ! @defined "$__releases__tested__assert__reason"; then
    @get __releases__tested__assert__get_3 "$__releases__tested__assert__landing" '.iid'
    log "check C: ${__releases__tested__assert__sha} holds the tree its landing run validated, the merge of $(forge__review_ref "$__releases__tested__assert__get_3")."
    return 0
  fi

  __releases__tested__report "$__releases__tested__assert__landing" "$__releases__tested__assert__reason" "$__releases__tested__assert__token"
  error "check C: ${__releases__tested__assert__reason}"
  return 1
}

: <<'PUB_FUN'
Prints why the commit <sha> fails check C against the <landing> the forge
answered for it, and nothing when it passes: the run on the merged head did
not pass, or the tree at <sha> is not the tree at that head. Fails when the
head cannot be brought into the clone.

  releases__tested__reason 7d68... "$landing"  ->  (nothing)
  releases__tested__reason 7d68... "$landing"  ->  the tree the trunk holds at 7d68... is not the tree the landing run validated at b3d2...

Usage: releases__tested__reason <sha> <landing>
PUB_FUN
releases__tested__reason() {
  @get __releases__tested__reason__head "$2" '.run.sha' ''
  @get __releases__tested__reason__state "$2" '.run.state' ''

  if [ "$__releases__tested__reason__state" != "$forge__OUTCOME_SUCCESS" ]; then
    @get __releases__tested__reason__get_4 "$2" '.head' ''
    printf 'the run on the merged head %s did not pass (%s), so the landing was not validated\n' \
      "${__releases__tested__reason__head:-$__releases__tested__reason__get_4}" \
      "${__releases__tested__reason__state:-none}"
    return 0
  fi

  @get __releases__tested__reason__get_5 "$2" '.head_ref' ''
  __releases__tested__hold "$__releases__tested__reason__head" "$__releases__tested__reason__get_5" || return 1
  if @is_true "$(git__trees_match "$1" "$__releases__tested__reason__head")"; then
    printf '\n'
    return 0
  fi

  printf 'the tree the trunk holds at %s is not the tree the landing run validated at %s, so what merged is not what was tested\n' "$1" "$__releases__tested__reason__head"
}

: <<'FUN'
Brings the merged head <sha> into the clone off origin's <ref> when the
merge did not bring it along, as a squashed one does not. Fails when the
clone cannot reach it either way.
FUN
__releases__tested__hold() {
  if git__commit_of "$1" >/dev/null 2>&1; then
    return 0
  fi

  git__remotes__fetch_ref origin "$2"
}

: <<'FUN'
Posts <reason> on the merge request the <landing> names, with <token>, so a
landing the check refused says why where its author reads; a note the forge
refuses is a warning, since the refusal stands either way.
FUN
__releases__tested__report() {
  @get __releases__tested__report__get_6 "$1" '.iid'
  @obj __releases__tested__report__options '.review_number' "$__releases__tested__report__get_6" '.token' "$3"

  forge__create_review_comment "$__releases__tested__report__options" "Check C refused this landing: ${2}. It earns no dev tag." >/dev/null \
    || warn "check C: the reason could not be posted on the merge request."
}
