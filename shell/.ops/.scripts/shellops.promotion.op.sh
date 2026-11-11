#!/usr/bin/env bash

import "$SHELLOPS_DIR/.scripts/_shellops_repositories.sh"

# file-label-check: allow -- a plugin under .scripts is keyed outside any library root and would read as an entrypoint
:<<'DOC'
shellops's own ladder: dev, alpha, beta, rc and stable, and what a tag at
each is put at across the three forge sets shellops promotes across,
internal, staging and public: ADR 000020's table. A site is one branch of
one of shellops' six copies (_shellops_repositories.sh), moved to the tag,
in the order they move. No rung asks for a certification for now: every
landing climbs to rc on the ladder's own plumbing, so the public copies
follow main, while the proofs behind alpha are rebuilt (OPS-1734,
OPS-1724). The certifications themselves, <rung>.certification.op.sh,
stay for the day they are asked for again. See lib/promotion/api.sh for
what the roles mean.
DOC
@promotion.shellops() {
  @summary() {
    println "dev, alpha, beta, rc, stable; ADR 000020's table across the internal, staging and public forges."
  }

  @sites() {
    __shellops_promotion__sites
  }

  @targets() {
    case "$1" in
      dev|alpha) @arr __promotion_shellops__out; println "$__promotion_shellops__out" ;;
      beta)      @arr __promotion_shellops__out origin-staging staging-gitlab-main staging-github-main; println "$__promotion_shellops__out" ;;
      rc)        @arr __promotion_shellops__out origin-staging origin-preview staging-gitlab-main staging-github-main public-gitlab-preview public-github-preview; println "$__promotion_shellops__out" ;;
      stable)    @arr __promotion_shellops__out origin-staging origin-preview origin-released staging-gitlab-main staging-github-main public-gitlab-preview public-gitlab-main public-github-preview public-github-main; println "$__promotion_shellops__out" ;;
      *)
        error "The shellops ladder climbs dev, alpha, beta, rc and stable, not '$1'."
        return 1
        ;;
    esac
  }

  @certifies() {
    case "$1" in
      dev|alpha|beta|rc|stable) @arr __promotion_shellops__out; println "$__promotion_shellops__out" ;;
      *)
        error "The shellops ladder climbs dev, alpha, beta, rc and stable, not '$1'."
        return 1
        ;;
    esac
  }
}

: <<'FUN'
The nine sites, each a branch of one copy: staging, preview and released on
origin, main on the staging copies, preview and main on the public ones.
FUN
__shellops_promotion__sites() {
  @obj __shellops_promotion__sites__out \
    '."origin-staging"'        "$(__shellops_promotion__branch origin staging)" \
    '."origin-preview"'        "$(__shellops_promotion__branch origin preview)" \
    '."origin-released"'       "$(__shellops_promotion__branch origin released)" \
    '."staging-gitlab-main"'   "$(__shellops_promotion__branch staging-gitlab main)" \
    '."staging-github-main"'   "$(__shellops_promotion__branch staging-github main)" \
    '."public-gitlab-preview"' "$(__shellops_promotion__branch public-gitlab preview)" \
    '."public-gitlab-main"'    "$(__shellops_promotion__branch public-gitlab main)" \
    '."public-github-preview"' "$(__shellops_promotion__branch public-github preview)" \
    '."public-github-main"'    "$(__shellops_promotion__branch public-github main)"
  println "$__shellops_promotion__sites__out"
}

: <<'FUN'
The branch site for <branch> in the copy named <repository>, carrying the
copy as _shellops_repositories.sh lists it.

  __shellops_promotion__branch staging-github main  ->  {"kind": "branch", "branch": "main", "repository": {"kind": "worktree", "forge": "github", ...}}
FUN
__shellops_promotion__branch() {
  __shellops_promotion__branch__repository="$(__shellops_repositories__one "$1")" || return 1

  @obj __shellops_promotion__branch__out '.kind' branch '.branch' "$2" '.repository' "$__shellops_promotion__branch__repository"
  println "$__shellops_promotion__branch__out"
}
