#!/bin/sh

import "$SHELLOPS_DIR/lib/git/commits.sh"

: <<'MODULE'
Whether a branch can be replaced by a commit without losing work: every
commit the branch holds and the commit does not has to be vouched for, by the
trailer `cherry-pick -x` writes naming a source the commit descends from;
failing a trailer, by carrying the same patch as a commit the target has and
the branch does not; failing both, by being an earlier draft of such a
commit, one that shares its parent and differs from it in the version files
alone, an earlier draft of a version record (ADR 000044). A forced branch
move reads this verdict before it runs (ADR 000021).
MODULE

# Why a side commit fails provenance, the two ways a move is refused.
@enum __git__provenance__REASON NO_TRAILER=no-trailer NOT_ANCESTOR=not-ancestor

# What each reason says to a person, keyed by the reason's word.
@obj __git__provenance__TEXTS \
  ".\"$__git__provenance__REASON_NO_TRAILER\"" "no cherry-pick trailer, no commit on the target carries the same patch, and none shares its parent and differs from it in the version files alone" \
  ".\"$__git__provenance__REASON_NOT_ANCESTOR\"" "the cherry-pick source is not an ancestor of the target"

: <<'PUB_FUN'
Judges whether <branch> may be force-moved to <target> without losing work.
Prints a struct: clean with the number of side commits vouched for, or the
first commit that is not and the reason, one of the __git__provenance__REASON
words, which git__provenance__reason_text spells out. <masked> names the files
a side commit may differ in from a twin on the target, the version files a
release rewrites; left out, no commit is vouched for by a twin.

  git__provenance released main                      ->  {"clean": true, "commits": 1}
  git__provenance released main '["manifest.json"]'  ->  {"clean": true, "commits": 1}
  git__provenance released main                      ->  {"clean": false, "commit": "3f1c...", "reason": "no-trailer"}

Usage: git__provenance <branch> <target> [<masked>]
PUB_FUN
git__provenance() {
  __git__provenance__branch="$1"
  __git__provenance__target="$2"
  __git__provenance__masked="$3"
  if ! @defined "$__git__provenance__masked"; then
    @arr __git__provenance__masked
  fi

  __git__provenance__commits="$(git__side_commits "$__git__provenance__branch" "$__git__provenance__target")" || return 1
  __git__provenance__patches="$(git__patch_ids "$__git__provenance__target" "^$__git__provenance__branch")" || return 1

  @find __git__provenance__offender __git__provenance__offends \
    "$__git__provenance__commits" \
    "$__git__provenance__target" \
    "$__git__provenance__patches" \
    "$__git__provenance__branch" \
    "$__git__provenance__masked"
  if @null __git__provenance__null_1; [ "$__git__provenance__offender" = "$__git__provenance__null_1" ]; then
    @len __git__provenance__len_2 "$__git__provenance__commits"
    @obj __git__provenance__out '.clean' true '.commits' "$__git__provenance__len_2"
    println "$__git__provenance__out"
    return 0
  fi

  @unwrap __git__provenance__sha "$__git__provenance__offender"
  __git__provenance__reason="$(__git__provenance__reason \
    "$__git__provenance__sha" \
    "$__git__provenance__target" \
    "$__git__provenance__patches" \
    "$__git__provenance__branch" \
    "$__git__provenance__masked"
  )"
  @obj __git__provenance__out \
    '.clean' false \
    '.commit' "$__git__provenance__sha" \
    '.reason' "$__git__provenance__reason"
  println "$__git__provenance__out"
}

: <<'PUB_FUN'
Prints what the reason <reason>, a word git__provenance answers with, says to
a person.

  git__provenance__reason_text not-ancestor  ->  the cherry-pick source is not an ancestor of the target

Usage: git__provenance__reason_text <reason>
PUB_FUN
git__provenance__reason_text() {
  @get __git__provenance__reason_text__out "$__git__provenance__TEXTS" ".\"$1\""
  println "$__git__provenance__reason_text__out"
}

: <<'FUN'
@find predicate: succeeds when the side commit $1 (wrapped) fails provenance
against target $2, given the target's patch ids $3, the branch $4 the commit
is on and the masked files $5.
FUN
__git__provenance__offends() {
  @unwrap __git__provenance__offends__sha "$1"

  @defined "$(__git__provenance__reason "$__git__provenance__offends__sha" "$2" "$3" "$4" "$5")"
}

: <<'FUN'
Prints why side commit $1 fails provenance against target $2, given the
target's patch ids $3, the branch $4 and the masked files $5; nothing when it
passes. A trailer naming an ancestor of the target passes; a trailer naming
anything else fails; no trailer passes when the target carries the same
patch, or when a twin on the target vouches for the commit.
FUN
__git__provenance__reason() {
  __git__provenance__reason__source="$(git__cherry_pick_source "$1")"

  if @defined "$__git__provenance__reason__source"; then
    if @is_true "$(git__is_ancestor "$__git__provenance__reason__source" "$2")"; then
      return 0
    fi
    println "$__git__provenance__REASON_NOT_ANCESTOR"
    return 0
  fi

  if @is_true "$(__git__provenance__patch_on_target "$1" "$3")"; then
    return 0
  fi
  if @is_true "$(__git__provenance__twin_on_target "$1" "$2" "$4" "$5")"; then
    return 0
  fi
  println "$__git__provenance__REASON_NO_TRAILER"
}

: <<'FUN'
Prints true when the patch of commit $1 is among the target's patch ids $2.
FUN
__git__provenance__patch_on_target() {
  @any __git__provenance__patch_on_target__out __git__provenance__patch_id_eq "$2" "$(git__patch_id "$1")"
  println "$__git__provenance__patch_on_target__out"
}

: <<'FUN'
@any predicate: succeeds when the patch id element $1 (wrapped) equals $2.
FUN
__git__provenance__patch_id_eq() {
  @unwrap __git__provenance__patch_id_eq__unwrap_3 "$1"
  [ "$__git__provenance__patch_id_eq__unwrap_3" = "$2" ]
}

: <<'FUN'
Prints true when a commit <target> holds and <branch> does not shares commit
<sha>'s parent and differs from it in the <masked> files alone, so <sha> is
an earlier draft of it; false otherwise, and for a root commit, which no twin
can share a parent with.

Usage: __git__provenance__twin_on_target <sha> <target> <branch> <masked>
FUN
__git__provenance__twin_on_target() {
  __git__provenance__twin_on_target__parent="$(git__commits__parent_of "$1")" || return 1
  if ! @defined "$__git__provenance__twin_on_target__parent"; then
    @false __git__provenance__twin_on_target__out
    println "$__git__provenance__twin_on_target__out"
    return 0
  fi

  __git__provenance__twin_on_target__twins="$(git__commits__with_parent \
    "$__git__provenance__twin_on_target__parent" \
    "$2" \
    "^$3"
  )" || return 1

  @any __git__provenance__twin_on_target__out __git__provenance__twin_matches "$__git__provenance__twin_on_target__twins" "$1" "$4"
  println "$__git__provenance__twin_on_target__out"
}

: <<'FUN'
@any predicate: succeeds when the wrapped commit $1 and commit $2 hold the
same files outside the masked files $3.
FUN
__git__provenance__twin_matches() {
  @unwrap __git__provenance__twin_matches__twin "$1"

  @is_true "$(git__trees_match_outside "$__git__provenance__twin_matches__twin" "$2" "$3")"
}
