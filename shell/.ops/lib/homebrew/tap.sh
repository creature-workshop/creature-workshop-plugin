#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/homebrew/api.sh" \
  "$SHELLOPS_DIR/lib/manifest/api.sh" \
  "$SHELLOPS_DIR/lib/releases/prepare.sh" \
  "$SHELLOPS_DIR/lib/versions/api.sh"

: <<'FRAGMENT'
The homebrew-tap target (declared in homebrew-tap.target.op.sh beside this
file): a Homebrew tap that gets the release's formula when a rung is reached.

A stable release writes the plain formula, a prerelease the -pre one, so
`brew install tool` gives the stable version and `brew install tool-pre` the
latest candidate. Which rungs reach the tap is the ladder's to say.

The formula downloads from the tag's GitHub release unless the target names
another base, and carries the sums of the tarballs in the build's output
directory. The push authenticates with FORGE_ADMIN_TOKEN.
FRAGMENT

__homebrew__tap__PRERELEASE_SUFFIX="-pre"
__homebrew__tap__DEFAULT_OUTDIR="./dist"

: <<'FUN'
Writes the formula for the release at <commit> to the site's tap. The site
names its `.tap`, and may name `.outdir` (./dist), `.asset_url` (the tag's
GitHub release) and `.artifact` (the command-name).

Usage: __homebrew__tap__reach <site> <commit>
FUN
__homebrew__tap__reach() {
  @get __homebrew__tap__reach__tap "$1" '.tap' ''
  if ! @defined "$__homebrew__tap__reach__tap"; then
    error "homebrew-tap: a site names its tap, and this one does not: $1"
    return 1
  fi

  __homebrew__tap__reach__tag="$(__homebrew__tap__tag_at "$2")" || return 1
  __homebrew__tap__reach__version="${__homebrew__tap__reach__tag#v}"
  __homebrew__tap__reach__formula="$(__homebrew__tap__formula_name "$__homebrew__tap__reach__version")"
  __homebrew__tap__reach__formula_rb="$(__homebrew__tap__formula_rb "$1" "$__homebrew__tap__reach__tag" "$__homebrew__tap__reach__formula")" || return 1

  __homebrew__tap__push "$__homebrew__tap__reach__tap" "$__homebrew__tap__reach__formula" "$__homebrew__tap__reach__version" "$__homebrew__tap__reach__formula_rb"
}

: <<'FUN'
Prints the tag of the release the manifest records, once it is confirmed to
point at <commit>; fails when it points elsewhere.

  __homebrew__tap__tag_at 0da8dc9  ->  1.2.3-rc.1
FUN
__homebrew__tap__tag_at() {
  __homebrew__tap__tag_at__tag="$(releases__release_recorded_tag)" || return 1
  __homebrew__tap__tag_at__at="$(git rev-parse --verify --quiet "${__homebrew__tap__tag_at__tag}^{commit}")"
  __homebrew__tap__tag_at__commit="$(git rev-parse --verify --quiet "${1}^{commit}")"

  if [ "$__homebrew__tap__tag_at__at" != "$__homebrew__tap__tag_at__commit" ]; then
    error "homebrew-tap: the recorded tag ${__homebrew__tap__tag_at__tag} is at ${__homebrew__tap__tag_at__at}, not at ${1}."
    return 1
  fi

  println "$__homebrew__tap__tag_at__tag"
}

: <<'FUN'
Prints the formula's name for version $1: the command-name, with -pre for a
prerelease.

  __homebrew__tap__formula_name 1.2.0       ->  tool
  __homebrew__tap__formula_name 1.2.0-rc.1  ->  tool-pre
FUN
__homebrew__tap__formula_name() {
  __homebrew__tap__formula_name__name="$(manifest__get command_name)"

  if versions__is_release_version "$1"; then
    println "$__homebrew__tap__formula_name__name"
    return 0
  fi

  printf '%s%s\n' "$__homebrew__tap__formula_name__name" "$__homebrew__tap__PRERELEASE_SUFFIX"
}

: <<'FUN'
Prints the formula <formula> for the release at <tag>, from the target's
tarballs. Fails when one is missing.

Usage: __homebrew__tap__formula_rb <target> <tag> <formula>
FUN
__homebrew__tap__formula_rb() {
  __homebrew__tap__formula_rb__metadata="$(__homebrew__tap__metadata "$1" "$3" "${2#v}")"
  __homebrew__tap__formula_rb__asset_url="$(__homebrew__tap__asset_url "$1" "$2")"
  @get __homebrew__tap__formula_rb__outdir "$1" '.outdir' "$__homebrew__tap__DEFAULT_OUTDIR"

  homebrew__generate_formula "$__homebrew__tap__formula_rb__metadata" "$__homebrew__tap__formula_rb__asset_url" "$__homebrew__tap__formula_rb__outdir"
}

: <<'FUN'
Prints the formula metadata for <target>: the manifest's defaults, named
<formula> at <version>, with the tarballs named as the target's `.artifact`
says when it says.

Usage: __homebrew__tap__metadata <target> <formula> <version>
FUN
__homebrew__tap__metadata() {
  @get __homebrew__tap__metadata__get_1 "$1" '.artifact' ''
  @patch __homebrew__tap__metadata__out "$(homebrew__new_formula_metadata)" \
    '.name'     "$2" \
    '.version'  "$3" \
    '.artifact' "$__homebrew__tap__metadata__get_1"
  println "$__homebrew__tap__metadata__out"
}

: <<'FUN'
Prints where <target>'s tarballs download from: its `.asset_url`, or the
GitHub release for <tag> when it names none.

  __homebrew__tap__asset_url '{"kind":"homebrew-tap","tap":"..."}' v1.2.0
    ->  https://github.com/org/tool/releases/download/v1.2.0
FUN
__homebrew__tap__asset_url() {
  @get __homebrew__tap__asset_url__base "$1" '.asset_url' ''
  if @defined "$__homebrew__tap__asset_url__base"; then
    println "$__homebrew__tap__asset_url__base"
    return 0
  fi

  printf 'https://github.com/%s/%s/releases/download/%s\n' "$(manifest__get org)" "$(manifest__get repo)" "$2"
}

: <<'FUN'
Pushes <formula_rb> to <tap> as Formula/<formula>.rb at <version>, with
FORGE_ADMIN_TOKEN on the push. Logs the formula and the tap, credentials
dropped.

Usage: __homebrew__tap__push <tap> <formula> <version> <formula_rb>
FUN
__homebrew__tap__push() {
  __homebrew__tap__push__url="$(__homebrew__tap__clone_url "$1" "${FORGE_ADMIN_TOKEN:-}")"

  homebrew__update_tap "$__homebrew__tap__push__url" "$4" "$2" "$3" || return 1

  log "Wrote Formula/${2}.rb ${3} to $(homebrew__redact_url "$1")."
}

: <<'FUN'
Prints the clone URL $1 with token $2 as its credentials, the form GitLab,
Forgejo and GitHub all accept on a push. With no scheme or no token the URL
is printed as it is.

  __homebrew__tap__clone_url https://git.example/org/tap.git s3cret  ->  https://oauth2:s3cret@git.example/org/tap.git
  __homebrew__tap__clone_url https://git.example/org/tap.git ""      ->  https://git.example/org/tap.git
FUN
__homebrew__tap__clone_url() {
  case "$1" in
    *://*) ;;
    *) printf '%s\n' "$1"; return 0 ;;
  esac
  if ! @defined "$2"; then
    println "$1"
    return 0
  fi

  printf '%s://oauth2:%s@%s\n' "${1%%://*}" "$2" "${1#*://}"
}
