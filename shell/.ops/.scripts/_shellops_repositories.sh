#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/structs/api.sh"

# file-label-check: allow -- a helper under .scripts is keyed outside any library root and would read as an entrypoint
: <<'FRAGMENT'
The six copies of shellops, one on each forge it promotes across, as
lib/git/forge.sh reads them: the box's GitLab as origin and the
Forgejo it mirrors to, the private copy on each public host, and the public
one on each. shellops' ladder puts its sites in them and its certifications
ask their forges. The list is shellops' own, not the promotion kind's.
FRAGMENT

__shellops_repositories__GITLAB_COM="https://gitlab.com"
__shellops_repositories__GITHUB_COM="https://github.com"

: <<'FUN'
Prints the six repositories as a struct object keyed by name.
FUN
__shellops_repositories__all() {
  @obj __shellops_repositories__all__obj_1 '.kind' worktree '.remote' origin '.forge' gitlab
  @true __shellops_repositories__all__true_2
  @obj __shellops_repositories__all__obj_3 '.kind' worktree '.forge' forgejo '.mirrored' "$__shellops_repositories__all__true_2"
  @obj __shellops_repositories__all__out \
    '.origin'           "$__shellops_repositories__all__obj_1" \
    '.mirror'           "$__shellops_repositories__all__obj_3" \
    '."staging-gitlab"' "$(__shellops_repositories__gitlab_com staging-gitlab creature-workshop/staging shellops)" \
    '."staging-github"' "$(__shellops_repositories__github staging-github creature-workshop shellops-staging)" \
    '."public-gitlab"'  "$(__shellops_repositories__gitlab_com public-gitlab creature-workshop shellops)" \
    '."public-github"'  "$(__shellops_repositories__github public-github creature-workshop shellops)"
  println "$__shellops_repositories__all__out"
}

: <<'FUN'
Prints the repository named <name>. Fails, saying which, for a name the
list does not have.

  __shellops_repositories__one mirror  ->  {"kind": "worktree", "forge": "forgejo", "mirrored": true}

Usage: __shellops_repositories__one <name>
FUN
__shellops_repositories__one() {
  __shellops_repositories__one__all="$(__shellops_repositories__all)"
  @null __shellops_repositories__one__null_4
  @get __shellops_repositories__one__repository "$__shellops_repositories__one__all" ".\"$1\"" "$__shellops_repositories__one__null_4"

  if @null __shellops_repositories__one__null_5; [ "$__shellops_repositories__one__repository" = "$__shellops_repositories__one__null_5" ]; then
    error "shellops has no repository named ${1}."
    return 1
  fi

  println "$__shellops_repositories__one__repository"
}

: <<'FUN'
Prints the repositories <names>, a struct array of names, each as {name,
repository}, in the order named. Fails, saying which, for a name the list
does not have.

  __shellops_repositories__named '["origin", "mirror"]'  ->  [{"name": "origin", "repository": {...}}, {"name": "mirror", "repository": {...}}]

Usage: __shellops_repositories__named <names>
FUN
__shellops_repositories__named() {
  @arr __shellops_repositories__named__all
  @join __shellops_repositories__named__join_6 "$1" ' '
  for __shellops_repositories__named__name in $__shellops_repositories__named__join_6; do
    __shellops_repositories__named__repository="$(__shellops_repositories__one "$__shellops_repositories__named__name")" || return 1
    @obj __shellops_repositories__named__one '.name' "$__shellops_repositories__named__name" '.repository' "$__shellops_repositories__named__repository"
    @push __shellops_repositories__named__all "$__shellops_repositories__named__all" "$__shellops_repositories__named__one"
  done
  println "$__shellops_repositories__named__all"
}

: <<'FUN'
Prints the repository for a copy of shellops on gitlab.com, reached as
<remote>, at the project <owner>/<repo> there, pushed to and asked with the
gitlab.com promotion token.

  __shellops_repositories__gitlab_com public-gitlab creature-workshop shellops
    ->  {"kind": "worktree", "forge": "gitlab", "remote": "public-gitlab", "host": "https://gitlab.com", "owner": "creature-workshop", "repo": "shellops", ...}
FUN
__shellops_repositories__gitlab_com() {
  @obj __shellops_repositories__gitlab_com__out \
    '.kind'      worktree \
    '.forge'     gitlab \
    '.remote'    "$1" \
    '.host'      "$__shellops_repositories__GITLAB_COM" \
    '.owner'     "$2" \
    '.repo'      "$3" \
    '.user'      oauth2 \
    '.token_env' GITLAB_PROMOTION_TOKEN
  println "$__shellops_repositories__gitlab_com__out"
}

: <<'FUN'
Prints the repository for a copy of shellops on github.com, reached as
<remote>, at the repository <owner>/<repo> there, pushed to and asked with
the github.com promotion token.

  __shellops_repositories__github staging-github creature-workshop shellops-staging
    ->  {"kind": "worktree", "forge": "github", "remote": "staging-github", "host": "https://github.com", "owner": "creature-workshop", "repo": "shellops-staging", ...}
FUN
__shellops_repositories__github() {
  @obj __shellops_repositories__github__out \
    '.kind'      worktree \
    '.forge'     github \
    '.remote'    "$1" \
    '.host'      "$__shellops_repositories__GITHUB_COM" \
    '.owner'     "$2" \
    '.repo'      "$3" \
    '.user'      x-access-token \
    '.token_env' GITHUB_PROMOTION_TOKEN
  println "$__shellops_repositories__github__out"
}
