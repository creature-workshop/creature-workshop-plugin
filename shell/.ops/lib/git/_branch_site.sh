#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/git/provenance.sh" \
  "$SHELLOPS_DIR/lib/releases/files.sh" \
  "$SHELLOPS_DIR/lib/git/repository.sh" \
  "$SHELLOPS_DIR/lib/git/forge.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'FRAGMENT'
What the branch site does (branch.site.op.sh beside this file): the site is
one branch of a repository, and a version is a commit the clone holds that
the branch moves to, through the repository kind (lib/git/repository.sh).

The site is {"kind": "branch", "branch": "published", "repository": {...}}:
  branch      The branch that is the site.
  repository  The repository the branch is in, as lib/git/repository.sh
              reads it. Left out, origin through a worktree. A mirrored one
              takes nothing: it shows what the repository it follows shows.

The version is {"commit": ..., "tag": ..., "lease": ...}:
  commit  The commit the branch moves to.
  tag     A tag the clone holds, pushed to the repository before the branch
          moves. Left out, no tag is pushed.
  lease   The token a checkout printed, for a version written into one: the
          branch moves only when it is still there, so a put after another
          put moved the branch fails rather than losing a version. Left out,
          the move is a promotion's (ADR 000020): the branch is created when
          the repository has none, left alone when it is already at the
          commit, and otherwise moved only when the provenance rule vouches
          for every commit it holds and the commit does not (ADRs 000021
          and 000044); one it cannot vouch for stops the move, named.
FRAGMENT

: <<'FUN'
Puts the version <version> at the site <site>, named <name>. Non-zero when
the site names no branch, the version names no commit or one the clone does
not hold, the repository refuses the tag, or the branch cannot move.

Usage: __git__branch_site__put <name> <site> <version>
FUN
__git__branch_site__put() {
  @get __git__branch_site__put__branch "$2" '.branch' ''
  __git__branch_site__put__repository="$(__git__branch_site__repository "$2")"
  @get __git__branch_site__put__commit "$3" '.commit' ''
  @get __git__branch_site__put__tag "$3" '.tag' ''

  if ! @defined "$__git__branch_site__put__branch"; then
    error "site: a branch site names its branch, and ${1} does not: $2"
    return 1
  fi
  if @is_true "$(git__forge__mirrored "$__git__branch_site__put__repository")"; then
    log "${1}: $(git__forge__name "$__git__branch_site__put__repository") is mirrored; it shows what the repository it follows shows."
    return 0
  fi
  if ! @defined "$__git__branch_site__put__commit"; then
    error "site: a version names its commit, and this one does not: $3"
    return 1
  fi
  if ! git__commit_of "$__git__branch_site__put__commit" > /dev/null 2>&1; then
    error "site: '${__git__branch_site__put__commit}' is not a commit this clone holds."
    return 1
  fi
  if @defined "$__git__branch_site__put__tag"; then
    __git__branch_site__push_tag "$__git__branch_site__put__repository" "$__git__branch_site__put__tag" || return 1
  fi

  if @is_true "$(__git__branch_site__leased "$3")"; then
    @get __git__branch_site__put__get_1 "$3" '.lease' ''
    git__repository__update "$__git__branch_site__put__repository" "$__git__branch_site__put__branch" "$__git__branch_site__put__get_1" "$__git__branch_site__put__commit"
  else
    __git__branch_site__promote "$__git__branch_site__put__repository" "$__git__branch_site__put__branch" "$__git__branch_site__put__commit"
  fi
}

: <<'FUN'
Prints the repository the branch site <site> names, or origin through a
worktree when it names none.
FUN
__git__branch_site__repository() {
  @obj __git__branch_site__repository__obj_2 '.kind' worktree '.remote' origin
  @get __git__branch_site__repository__out "$1" '.repository' "$__git__branch_site__repository__obj_2"
  println "$__git__branch_site__repository__out"
}

: <<'FUN'
Prints true when the version <version> carries a lease, however empty.
FUN
__git__branch_site__leased() {
  if @keys __git__branch_site__leased__keys_3 "$1"; @println "$__git__branch_site__leased__keys_3" | grep -qFx -- lease; then
    @true __git__branch_site__leased__out
    println "$__git__branch_site__leased__out"
  else
    @false __git__branch_site__leased__out
    println "$__git__branch_site__leased__out"
  fi
}

: <<'FUN'
Pushes <tag> to <repository>, saying so, and fails, saying which repository
refused it, when it is refused.

Usage: __git__branch_site__push_tag <repository> <tag>
FUN
__git__branch_site__push_tag() {
  __git__branch_site__push_tag__name="$(git__forge__name "$1")"
  @get __git__branch_site__push_tag__remote "$1" '.remote' 'this clone'

  if ! git__repository__tag "$1" "$2"; then
    error "site: ${__git__branch_site__push_tag__name} (${__git__branch_site__push_tag__remote}) refused the tag ${2}."
    return 1
  fi
  log "Pushed ${2} to ${__git__branch_site__push_tag__name} (${__git__branch_site__push_tag__remote})."
}

: <<'FUN'
Moves <branch> in <repository> to <commit> as a promotion does: created when
the repository has none, left alone when already there, and otherwise moved
once the provenance rule vouches for every commit it holds and the commit
does not.

Usage: __git__branch_site__promote <repository> <branch> <commit>
FUN
__git__branch_site__promote() {
  @get __git__branch_site__promote__remote "$1" '.remote' 'this clone'
  __git__branch_site__promote__current="$(git__repository__tip "$1" "$2")" || return 1

  if [ "$__git__branch_site__promote__current" = "$3" ]; then
    log "${2} on ${__git__branch_site__promote__remote} is already at ${3}; nothing to move."
    return 0
  fi
  if @defined "$__git__branch_site__promote__current"; then
    __git__branch_site__refuse_unless_vouched "$__git__branch_site__promote__remote" "$2" "$__git__branch_site__promote__current" "$3" || return 1
  fi

  git__repository__force "$1" "$2" "$3" || return 1
  log "Moved ${2} on ${__git__branch_site__promote__remote}: ${__git__branch_site__promote__current:-(none)} -> ${3}."
}

: <<'FUN'
Fails, naming the commit, when a commit <branch> on <remote> holds at
<current> is not vouched for against <commit>; says how many were when every
one is.

Usage: __git__branch_site__refuse_unless_vouched <remote> <branch> <current> <commit>
FUN
__git__branch_site__refuse_unless_vouched() {
  __git__branch_site__refuse_unless_vouched__masked="$(releases__release_files)" || return 1
  __git__branch_site__refuse_unless_vouched__verdict="$(git__provenance "$3" "$4" "$__git__branch_site__refuse_unless_vouched__masked")" || return 1

  if @get __git__branch_site__refuse_unless_vouched__get_4 "$__git__branch_site__refuse_unless_vouched__verdict" '.clean'; @is_true "$__git__branch_site__refuse_unless_vouched__get_4"; then
    @get __git__branch_site__refuse_unless_vouched__get_5 "$__git__branch_site__refuse_unless_vouched__verdict" '.commits'
    log "${2} on ${1}: $__git__branch_site__refuse_unless_vouched__get_5 side commit(s) vouched for."
    return 0
  fi

  @get __git__branch_site__refuse_unless_vouched__reason "$__git__branch_site__refuse_unless_vouched__verdict" '.reason'
  __git__branch_site__refuse_unless_vouched__text="$(git__provenance__reason_text "$__git__branch_site__refuse_unless_vouched__reason")"
  @get __git__branch_site__refuse_unless_vouched__get_6 "$__git__branch_site__refuse_unless_vouched__verdict" '.commit'
  error "site: refusing to move ${2} on ${1}: commit $__git__branch_site__refuse_unless_vouched__get_6 has ${__git__branch_site__refuse_unless_vouched__text}."
  return 1
}
