#!/bin/sh

:<<'FRAGMENT'
Which GitLab project a call addresses: the subgroup-aware project path and the encoded id REST wants, resolved from the options, CI, the origin remote or the manifest.
FRAGMENT

:<<'FUN'
Resolves the full project path (e.g. "group/subgroup/repo") for the
selected project. Unlike Forgejo's flat owner/repo, GitLab supports
nested subgroups, so we resolve through a fallback chain rather than a
single source:

  1. explicit .owner/.repo in options (caller override)
  2. CI_PROJECT_PATH       (always set in GitLab CI; subgroup-correct)
  3. the origin git remote (works on and off CI; subgroup-correct)
  4. manifest org/repo     (flat fallback for the simple case)

Keeping manifest.json as a minimal logical identity (org/repo) means
repos don't have to hand-encode their namespace; the concrete path is
discovered from the environment. See follow-up: generalize org/repo
across GitHub/GitLab/Gitea/Woodpecker.

Usage:
  __gitlab__project_path '{"owner":"a","repo":"b"}'   # -> a/b
FUN
__gitlab__project_path() {
  @let "$1" __gitlab__project_path__ owner repo

  # Explicit owner/repo wins -- but only as a genuine override, not when it
  # merely echoes the flat manifest identity. The forge_new_*_options
  # constructors backfill manifest org/repo into every options blob, and the
  # manifest is namespace-flat: trusting it here collapses a nested subgroup
  # path (group/sub/repo -> group/repo). When the supplied values are just the
  # manifest identity we fall through to the subgroup-correct sources below.
  if @defined "$__gitlab__project_path__owner" && @defined "$__gitlab__project_path__repo" \
    && @is_false "$(__gitlab__is_manifest_identity "$__gitlab__project_path__owner" "$__gitlab__project_path__repo")"; then
    printf '%s/%s\n' "$__gitlab__project_path__owner" "$__gitlab__project_path__repo"
    return 0
  fi

  if @defined "${CI_PROJECT_PATH:-}"; then
    println "$CI_PROJECT_PATH"
    return 0
  fi

  if __gitlab__project_path__path="$(__gitlab__project_path_from_remote)" && @defined "$__gitlab__project_path__path"; then
    println "$__gitlab__project_path__path"
    return 0
  fi

  __gitlab__project_path__owner="$(manifest__get org)"
  __gitlab__project_path__repo="$(manifest__get repo)"
  if @defined "$__gitlab__project_path__owner" && @defined "$__gitlab__project_path__repo"; then
    printf '%s/%s\n' "$__gitlab__project_path__owner" "$__gitlab__project_path__repo"
    return 0
  fi

  __gitlab__project_path__dump_1="$(forge__base__options_without_token "$1")"
  error "Cannot resolve project path. Set CI_PROJECT_PATH, an origin remote, or manifest org/repo: $__gitlab__project_path__dump_1"
  @unlet __gitlab__project_path__ owner repo
  return 1
}

:<<'FUN'
True when owner/repo equal the flat manifest identity (manifest org/repo).

These are the values forge_new_*_options backfill, so this is how
__gitlab__project_path tells a real caller override from a manifest
backfill. Answers false when the manifest can't be read, so explicit owner/repo
still wins off-CI / in unit tests without a manifest.

Usage: if @is_true "$(__gitlab__is_manifest_identity "$owner" "$repo")"; then ... fi
FUN
__gitlab__is_manifest_identity() {
  __gitlab__is_manifest_identity__m_org="$(manifest__get org 2>/dev/null)" || { @false __gitlab__is_manifest_identity__out; println "$__gitlab__is_manifest_identity__out"; return; }
  __gitlab__is_manifest_identity__m_repo="$(manifest__get repo 2>/dev/null)" || { @false __gitlab__is_manifest_identity__out; println "$__gitlab__is_manifest_identity__out"; return; }

  if [ "$1" = "$__gitlab__is_manifest_identity__m_org" ] && [ "$2" = "$__gitlab__is_manifest_identity__m_repo" ]; then
    @true __gitlab__is_manifest_identity__out
    println "$__gitlab__is_manifest_identity__out"
  else
    @false __gitlab__is_manifest_identity__out
    println "$__gitlab__is_manifest_identity__out"
  fi
}

:<<'FUN'
Parses the "group/.../repo" path from the origin git remote, dropping
scheme, embedded credentials, host/port, and the trailing .git. Returns
non-zero (and empty) when there is no usable remote.

Handles:
  https://user:tok@host/group/sub/repo.git
  ssh://git@host:2222/group/sub/repo.git
  git@host:group/repo.git
FUN
__gitlab__project_path_from_remote() {
  __gitlab__project_path_from_remote__url="$(git remote get-url origin 2>/dev/null)" || return 1
  ! @defined "$__gitlab__project_path_from_remote__url" && return 1

  case "$__gitlab__project_path_from_remote__url" in
    *://*)
      # [user@]host[:port]/group/.../repo.git
      __gitlab__project_path_from_remote__rest="${__gitlab__project_path_from_remote__url#*://}"
      # host[:port]/group/.../repo.git
      __gitlab__project_path_from_remote__rest="${__gitlab__project_path_from_remote__rest#*@}"
      # group/.../repo.git
      __gitlab__project_path_from_remote__path="${__gitlab__project_path_from_remote__rest#*/}"
      ;;
    *@*:*)
      # git@host:group/repo.git -> group/repo.git
      __gitlab__project_path_from_remote__path="${__gitlab__project_path_from_remote__url#*:}"
      ;;
    *)
      return 1
      ;;
  esac

  __gitlab__project_path_from_remote__path="${__gitlab__project_path_from_remote__path%.git}"
  __gitlab__project_path_from_remote__path="${__gitlab__project_path_from_remote__path%/}"

  # No path component (e.g. URL was just a host) -> unusable.
  if ! @defined "$__gitlab__project_path_from_remote__path" || [ "$__gitlab__project_path_from_remote__path" = "$__gitlab__project_path_from_remote__url" ]; then
    return 1
  fi
  case "$__gitlab__project_path_from_remote__path" in
    */*) ;;
    *) return 1 ;;
  esac

  println "$__gitlab__project_path_from_remote__path"
}

:<<'FUN'
Returns the URL-encoded project ID for REST endpoints. GitLab REST accepts
either a numeric ID or a URL-encoded full path. Every path separator is
encoded so nested subgroups resolve correctly.

Usage:
  __gitlab__project_id '{"owner":"a","repo":"b"}'        # -> a%2Fb
  CI_PROJECT_PATH=g/sub/r __gitlab__project_id '{}'      # -> g%2Fsub%2Fr
FUN
__gitlab__project_id() {
  __gitlab__project_id__path="$(__gitlab__project_path "$1")" || return 1
  string__replace "$__gitlab__project_id__path" "/" "%2F"
}
