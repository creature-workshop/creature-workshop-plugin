#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/forge/api.sh" \
  "$SHELLOPS_DIR/lib/git/remotes.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
What a repository knows about the forge it lives on, when it lives on one,
read off the repository struct (lib/git/repository.sh): how the clone
reaches it, which forge runs its pipelines, and whether its pipeline on a
commit is this very run. A repository that names no forge lives on none:
git alone reaches it, nothing runs a pipeline there, and nothing is asked
of it. Beside `.kind` and `.remote`, a repository on a forge carries:

  forge      The adaptor that asks the forge about a run: gitlab, forgejo
             or github. A repository naming none lives on no forge.
  host       The forge's server, for a copy elsewhere than the clone came
             from. A repository with a host is one the clone has to be told
             about: its remote is pointed at <host>/<owner>/<repo>.git, and
             pushes there go as <user> with the token in the variable
             <token_env> names.
  owner      The repository's namespace on that forge.
  repo       The repository's name there.
  user       The user the token belongs to.
  token_env  The variable holding the token.
  candidate  The branch the forge runs a candidate on; candidate unless
             the repository names another.
  mirrored   true for a repository that receives its refs from another one
             on the same ladder. Nothing is put there; it shows what that
             one shows, and its forge runs its own pipeline on what arrives.
MODULE

# CONST: The branch a forge runs a candidate on when the repository names none.
__git__forge__CANDIDATE="candidate"

: <<'PUB_FUN'
Prints the name a reader knows the repository <repository> by: its forge
adaptor's name, or its remote for one naming no adaptor.

  git__forge__name '{"kind": "worktree", "remote": "staging-github", "forge": "github"}'  ->  github
  git__forge__name '{"kind": "worktree", "remote": "origin"}'                             ->  origin

Usage: git__forge__name <repository>
PUB_FUN
git__forge__name() {
  @get __git__forge__name__forge "$1" '.forge' ''

  if @defined "$__git__forge__name__forge"; then
    println "$__git__forge__name__forge"
  else
    @get __git__forge__name__out "$1" '.remote' ''
    println "$__git__forge__name__out"
  fi
}

: <<'PUB_FUN'
Prints true when the repository <repository> lives on a forge, naming the
adaptor that asks it about a run, and false for one git alone reaches.

  git__forge__named '{"kind": "worktree", "remote": "origin", "forge": "gitlab"}'  ->  true
  git__forge__named '{"kind": "worktree", "remote": "origin"}'                     ->  false

Usage: git__forge__named <repository>
PUB_FUN
git__forge__named() {
  @get __git__forge__named__get_1 "$1" '.forge' ''
  @succeeds __git__forge__named__out @defined "$__git__forge__named__get_1"
  println "$__git__forge__named__out"
}

: <<'PUB_FUN'
Prints true when the repository <repository> names a host: a copy elsewhere
than the clone came from, which a candidate is pushed to and run on.

Usage: git__forge__hosted <repository>
PUB_FUN
git__forge__hosted() {
  @get __git__forge__hosted__get_2 "$1" '.host' ''
  @succeeds __git__forge__hosted__out @defined "$__git__forge__hosted__get_2"
  println "$__git__forge__hosted__out"
}

: <<'PUB_FUN'
Prints true when the repository <repository> receives its refs from another
one, so nothing is put there.

Usage: git__forge__mirrored <repository>
PUB_FUN
git__forge__mirrored() {
  @false __git__forge__mirrored__false_3
  @get __git__forge__mirrored__out "$1" '.mirrored' "$__git__forge__mirrored__false_3"
  println "$__git__forge__mirrored__out"
}

: <<'PUB_FUN'
Prints true when <repository> is the one this run is on, so its pipeline on
the commit is this very run and not one to wait for: it names the run's own
adaptor and no host. False for every other repository, a mirror and one on
no forge among them.

  <SHELLOPS_FORGE=gitlab>  git__forge__is_this_run '{"remote": "origin", "forge": "gitlab"}'                ->  true
  <SHELLOPS_FORGE=gitlab>  git__forge__is_this_run '{"remote": "origin"}'                                   ->  false
  <SHELLOPS_FORGE=gitlab>  git__forge__is_this_run '{"forge": "forgejo", "mirrored": true}'                 ->  false
  <SHELLOPS_FORGE=gitlab>  git__forge__is_this_run '{"forge": "gitlab", "host": "https://gitlab.com", ...}'  ->  false

Usage: git__forge__is_this_run <repository>
PUB_FUN
git__forge__is_this_run() {
  @succeeds __git__forge__is_this_run__out __git__forge__this_run "$1"
  println "$__git__forge__is_this_run__out"
}

: <<'FUN'
Succeeds when <repository> names the run's own adaptor and no host; fails
otherwise. The command git__forge__is_this_run wraps.

Usage: __git__forge__this_run <repository>
FUN
__git__forge__this_run() {
  @get __git__forge__this_run__host "$1" '.host' ''
  @get __git__forge__this_run__forge "$1" '.forge' ''
  ! @defined "$__git__forge__this_run__host" \
    && [ "$__git__forge__this_run__forge" = "$(forge__selected)" ]
}

: <<'PUB_FUN'
Prints the branch the forge of <repository> runs a candidate on: the one it
names, or candidate.

  git__forge__candidate_branch '{"remote": "origin"}'                          ->  candidate
  git__forge__candidate_branch '{"remote": "elsewhere", "candidate": "next"}'  ->  next

Usage: git__forge__candidate_branch <repository>
PUB_FUN
git__forge__candidate_branch() {
  @get __git__forge__candidate_branch__out "$1" '.candidate' "$__git__forge__CANDIDATE"
  println "$__git__forge__candidate_branch__out"
}

: <<'PUB_FUN'
Prints the remote this clone reaches <repository> by, with the clone ready
to push there. A repository naming only a remote is reached as it is. One
naming a host has its remote pointed at the repository on that host, and
the host authorized to sign in with the token in the variable it names.
Fails when the repository names no remote, or names a token variable that
is unset.

  git__forge__ready '{"kind": "worktree", "remote": "origin"}'  ->  origin
  git__forge__ready '{"kind": "worktree", "remote": "staging-github", "host": "https://github.com", "owner": "creature-workshop", "repo": "shellops-staging", "user": "x-access-token", "token_env": "GITHUB_PROMOTION_TOKEN"}'
    ->  staging-github, pointed at https://github.com/creature-workshop/shellops-staging.git

Usage: git__forge__ready <repository>
PUB_FUN
git__forge__ready() {
  @get __git__forge__ready__remote "$1" '.remote' ''
  @get __git__forge__ready__host "$1" '.host' ''

  if ! @defined "$__git__forge__ready__remote"; then
    error "repository: a repository names the remote this clone reaches it by, and this one does not: $1"
    return 1
  fi

  if @defined "$__git__forge__ready__host"; then
    __git__forge__ready__token_env="$(__git__forge__token_env "$1")" || return 1
    git__remote_set "$__git__forge__ready__remote" "$(__git__forge__url "$1")"
    @get __git__forge__ready__get_5 "$1" '.user' ''
    git__authorize_host "$__git__forge__ready__host" "$__git__forge__ready__get_5" "$__git__forge__ready__token_env"
  fi

  println "$__git__forge__ready__remote"
}

: <<'FUN'
Prints the clone URL of <repository> on its host.

  __git__forge__url '{"host": "https://gitlab.com", "owner": "creature-workshop/staging", "repo": "shellops"}'
    ->  https://gitlab.com/creature-workshop/staging/shellops.git
FUN
__git__forge__url() {
  @get __git__forge__url__get_6 "$1" '.host' ''
  @get __git__forge__url__get_7 "$1" '.owner' ''
  @get __git__forge__url__get_8 "$1" '.repo' ''
  printf '%s/%s/%s.git\n' "$__git__forge__url__get_6" "$__git__forge__url__get_7" "$__git__forge__url__get_8"
}

: <<'FUN'
Prints the name of the variable <repository> keeps its token in, once that
variable holds one. Fails, naming the variable, when the repository names
none or the variable is unset: a push to a repository with a host never
goes unauthenticated.
FUN
__git__forge__token_env() {
  @get __git__forge__token_env__env "$1" '.token_env' ''

  if ! @defined "$__git__forge__token_env__env"; then
    error "repository: a repository with a host names the variable its token is in, and this one does not: $1"
    return 1
  fi

  eval "__git__forge__token_env__value=\"\${${__git__forge__token_env__env}:-}\""
  if ! @defined "$__git__forge__token_env__value"; then
    error "repository: ${__git__forge__token_env__env} is unset; nothing is pushed to $(git__forge__name "$1") without it."
    return 1
  fi

  println "$__git__forge__token_env__env"
}
