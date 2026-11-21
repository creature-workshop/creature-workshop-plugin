#!/bin/sh

: <<'MODULE'
Fetching the tree of one commit of a repository, and the rules git applies
to the repositories a .gitmodules names: a relative repository resolves
against the one that declared it, and a repository's own is its origin.
The module is plain shell and calls no structs verb: a boot fetches trees
before the structs library loads.

  git__trees__fetch https://forge/ksoft/strata.git 73e6... /p/strata
    ->  /p/strata holds the files of 73e6..., checked out
  git__trees__gitlinks /p/strata
    ->  shell/.logs 7f3dd9d59cd09d237c70e50bb68e795ebf56dc57
        shell/.ops 57bcedf07ccd40fcf477e9bbba59acb26a2c97d9
  git__trees__url ../strata.git https://forge/ksoft/shellops.git
    ->  https://forge/ksoft/strata.git
MODULE

# CONST: The awk that reads the gitlinks off an ls-tree listing.
__git__trees__GITLINKS_AWK="$SHELLOPS_DIR/lib/git/trees/gitlinks.awk"

: <<'PUB_FUN'
Checks the commit <commit> of the repository <url> out at <dir>, fetching
that commit alone, so <dir> holds the commit's files and a repository
that knows no other commit. Fails, printing nothing, when the commit
cannot be fetched; what stands at <dir> by then is left for the caller to
remove.

Usage: git__trees__fetch <url> <commit> <dir>
PUB_FUN
git__trees__fetch() {
  __git__trees__fetch__url="$(git__trees__fetch_url "$1")"
  mkdir -p "$3" || return 1
  __git__trees__git -C "$3" init -q || return 1
  __git__trees__git -C "$3" fetch -q --depth 1 "$__git__trees__fetch__url" "$2" 2>/dev/null || return 1
  __git__trees__git -C "$3" -c advice.detachedHead=false checkout -q FETCH_HEAD
}

: <<'PUB_FUN'
Prints the submodules the checkout at <dir> pins, one "<path> <commit>"
per line, and nothing when it pins none.

  git__trees__gitlinks /p/strata
    ->  shell/.logs 7f3dd9d59cd09d237c70e50bb68e795ebf56dc57
        shell/.ops 57bcedf07ccd40fcf477e9bbba59acb26a2c97d9

Usage: git__trees__gitlinks <dir>
PUB_FUN
git__trees__gitlinks() {
  __git__trees__git -C "$1" ls-tree -r HEAD \
    | awk -f "$__git__trees__GITLINKS_AWK"
}

: <<'PUB_FUN'
Prints the repository <declared> names, resolved against <base>: a URL
or an absolute path as it is, and a relative one as git resolves a
.gitmodules URL, each "../" climbing one segment from <base> itself.

  git__trees__url ../strata.git https://forge/ksoft/shellops.git
    ->  https://forge/ksoft/strata.git
  git__trees__url ../libraries/shell-goldens.git https://forge/ksoft/strata.git
    ->  https://forge/ksoft/libraries/shell-goldens.git
  git__trees__url /forge/strata.git https://forge/ksoft/shellops.git
    ->  /forge/strata.git

Usage: git__trees__url <declared> <base>
PUB_FUN
git__trees__url() {
  if [ "$(git__trees__url_is_absolute "$1")" = true ]; then  # structs-lint: allow -- plain shell, loaded before structs
    println "$1"
    return 0
  fi
  __git__trees__url__base="$2"
  __git__trees__url__rest="$1"
  while [ "${__git__trees__url__rest#../}" != "$__git__trees__url__rest" ]; do
    __git__trees__url__base="${__git__trees__url__base%/*}"
    __git__trees__url__rest="${__git__trees__url__rest#../}"
  done
  printf '%s/%s\n' "$__git__trees__url__base" "$__git__trees__url__rest"
}

: <<'PUB_FUN'
Prints true when <url> names a repository on its own: a URL with a
scheme, an absolute path, or git's scp-like "user@host:path" form. Prints
false for a path such as "../strata.git", which git resolves against the
repository that declared it.

  git__trees__url_is_absolute https://forge/ksoft/strata.git  ->  true
  git__trees__url_is_absolute ../strata.git                   ->  false

Usage: git__trees__url_is_absolute <url>
PUB_FUN
git__trees__url_is_absolute() {
  case "$1" in
    *://* | /* | *@*:*)
      println true
      ;;
    *)
      println false
      ;;
  esac
}

: <<'PUB_FUN'
Prints the URL of the repository <root>'s origin remote. Fails, saying so,
when the repository has none.

Usage: git__trees__origin <root>
PUB_FUN
git__trees__origin() {
  if ! __git__trees__git -C "$1" remote get-url origin 2>/dev/null; then
    error "$1 has no origin to find its dependencies beside"
    return 1
  fi
}

: <<'PUB_FUN'
Prints the URL git fetches <url> from. In a CI job, a URL on the CI
server carries the job token, which is how a job reads a private
repository the project is allowed to; every other URL is printed as it
is. The declared URL, not this one, is what a message names.

  CI_SERVER_URL=https://forge CI_JOB_TOKEN=t \
    git__trees__fetch_url https://forge/ksoft/strata.git
    ->  https://gitlab-ci-token:t@forge/ksoft/strata.git

Usage: git__trees__fetch_url <url>
PUB_FUN
git__trees__fetch_url() {
  if [ -z "${CI_JOB_TOKEN:-}" ] || [ -z "${CI_SERVER_URL:-}" ]; then
    println "$1"
    return 0
  fi
  case "$1" in
    "$CI_SERVER_URL"/*)
      printf '%s://gitlab-ci-token:%s@%s%s\n' \
        "${CI_SERVER_URL%%://*}" \
        "$CI_JOB_TOKEN" \
        "${CI_SERVER_URL#*://}" \
        "${1#"$CI_SERVER_URL"}"
      ;;
    *)
      println "$1"
      ;;
  esac
}

: <<'FUN'
Runs git with <args> on the repository the arguments name, whatever
repository the caller is in. A git hook exports GIT_DIR and the variables
beside it, and git obeys them over -C, so a shell loaded inside a hook would
otherwise act on the hook's repository.

Usage: __git__trees__git <args...>
FUN
__git__trees__git() {
  (
    # shellcheck disable=SC2046  # one variable name per word, on purpose
    unset $(git rev-parse --local-env-vars)
    git "$@"
  )
}
