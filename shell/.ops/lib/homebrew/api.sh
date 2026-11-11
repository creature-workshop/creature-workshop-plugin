#!/bin/sh

import "$SHELLOPS_DIR/lib/tarball/api.sh"
import "$SHELLOPS_DIR/lib/http/api.sh"
import "$SHELLOPS_DIR/lib/manifest/api.sh"

: <<'MODULE'
Homebrew formula generation and tap management.

Generates Ruby formula files for binary taps and handles
the clone/update/commit/push cycle for tap repositories.
MODULE

HOMEBREW_METADATA_SCHEMA="${SHELLOPS_DIR}/lib/homebrew/formula_metadata.schema.json"

: <<'CONST'
The triple the formula's Apple Silicon slot is built for; the template
fills four such slots.
CONST
__homebrew__TRIPLE_DARWIN_ARM="aarch64-apple-darwin"

# CONST: The triple of the Intel Mac slot.
__homebrew__TRIPLE_DARWIN_X86="x86_64-apple-darwin"

# CONST: The triple of the ARM Linux slot.
__homebrew__TRIPLE_LINUX_ARM="aarch64-unknown-linux-gnu"

# CONST: The triple of the x86 Linux slot.
__homebrew__TRIPLE_LINUX_X86="x86_64-unknown-linux-gnu"

: <<'PUB_FUN'
The formula metadata a project's manifest implies: the formula, its binary
and its tarballs all named by the command-name, the manifest's description,
the GitHub repository as the homepage, MIT, and no version yet. A caller
patches in the version and whatever else differs.

  name         the formula: the file under Formula/ and the Ruby class
  version      the release version the formula installs
  description  the formula's one line
  homepage     the project's URL
  license      the SPDX identifier
  bin          the binary the formula installs
  artifact     the name the tarballs carry, <artifact>-<version>-<triple>.tar.gz

Usage: homebrew__new_formula_metadata
PUB_FUN
homebrew__new_formula_metadata() {
  __homebrew__new_formula_metadata__command="$(manifest__get command_name)"

  @obj __homebrew__new_formula_metadata__out \
    '.name'        "$__homebrew__new_formula_metadata__command" \
    '.version'     "" \
    '.description' "$(manifest__get description)" \
    '.homepage'    "https://github.com/$(manifest__get org)/$(manifest__get repo)" \
    '.license'     "MIT" \
    '.bin'         "$__homebrew__new_formula_metadata__command" \
    '.artifact'    "$__homebrew__new_formula_metadata__command"
  println "$__homebrew__new_formula_metadata__out"
}

: <<'PUB_FUN'
Builds and validates a formula metadata JSON object.

Required:
  name     - formula/binary name
  version  - release version

Optional (pass empty string to omit):
  description - one-line description
  homepage    - project URL
  license     - SPDX identifier (defaults to MIT)
  bin         - binary filename if different from name

  homebrew__build_metadata "insights" "1.2.0" "Knowledge management" "https://..." "MIT" ""
PUB_FUN
homebrew__build_metadata() {
  __homebrew__build_metadata__description="${3:-}"
  __homebrew__build_metadata__homepage="${4:-}"
  __homebrew__build_metadata__bin_name="${6:-}"

  @obj __homebrew__build_metadata__metadata '.name' "$1" '.version' "$2" '.license' "${5:-MIT}"

  [ -n "$__homebrew__build_metadata__description" ] && @set __homebrew__build_metadata__metadata "$__homebrew__build_metadata__metadata" '.description' "$__homebrew__build_metadata__description"
  [ -n "$__homebrew__build_metadata__homepage" ] && @set __homebrew__build_metadata__metadata "$__homebrew__build_metadata__metadata" '.homepage' "$__homebrew__build_metadata__homepage"
  [ -n "$__homebrew__build_metadata__bin_name" ] && @set __homebrew__build_metadata__metadata "$__homebrew__build_metadata__metadata" '.bin' "$__homebrew__build_metadata__bin_name"

  if ! @validate "$__homebrew__build_metadata__metadata" "$HOMEBREW_METADATA_SCHEMA"; then
    return 1
  fi

  echo "$__homebrew__build_metadata__metadata"
}

: <<'PUB_FUN'
Generates a Homebrew formula (.rb) for a pre-built binary distributed
across macOS and Linux for both x86_64 and aarch64.

Computes SHA256 hashes from local tarballs in asset_dir.

Parameters:
  metadata  JSON object:
              name        - formula name: the file and the Ruby class (e.g. "tool")
              version     - release version (e.g. "1.2.0")
              description - one-line description
              homepage    - project URL
              license     - SPDX identifier (e.g. "MIT")
              bin         - binary filename to install (defaults to name)
              artifact    - name the tarballs carry, <artifact>-<version>-<triple>.tar.gz,
                            in the URLs and on disk (defaults to name)
  asset_url - base URL where release tarballs are hosted
  asset_dir - local directory containing the tarballs (for SHA256 computation)

Writes the formula to stdout.

  homebrew__generate_formula "$metadata" "https://example.com/releases/v1.2.0" "./dist"
PUB_FUN
homebrew__generate_formula() {
  __homebrew__generate_formula__metadata="$(__homebrew__metadata_with_defaults "$1")"
  __homebrew__generate_formula__asset_url="$2"
  __homebrew__generate_formula__asset_dir="$3"

  @let "$__homebrew__generate_formula__metadata" __homebrew__generate_formula__ artifact version

  __homebrew__generate_formula__sums="$(__homebrew__sums "$__homebrew__generate_formula__artifact" "$__homebrew__generate_formula__version" "$__homebrew__generate_formula__asset_dir")"
  __homebrew__generate_formula__status=$?
  if [ "$__homebrew__generate_formula__status" -eq 0 ]; then
    __homebrew__render_formula "$__homebrew__generate_formula__metadata" "$__homebrew__generate_formula__asset_url" "$__homebrew__generate_formula__sums"
    __homebrew__generate_formula__status=$?
  fi
  @unlet __homebrew__generate_formula__ artifact version
  return "$__homebrew__generate_formula__status"
}

: <<'FUN'
Prints the metadata $1 with bin and artifact filled in where it leaves them
empty: both default to the formula's name.

  __homebrew__metadata_with_defaults '{"name":"tool","version":"1.0.0"}'
    ->  {"name":"tool","version":"1.0.0","bin":"tool","artifact":"tool"}
FUN
__homebrew__metadata_with_defaults() {
  @let "$1" __homebrew__metadata_with_defaults__ name bin artifact
  @set __homebrew__metadata_with_defaults__defaults "$1" \
    '.bin'      "$__homebrew__metadata_with_defaults__name" \
    '.artifact' "$__homebrew__metadata_with_defaults__name"

  @patch __homebrew__metadata_with_defaults__out "$__homebrew__metadata_with_defaults__defaults" \
    '.bin'      "$__homebrew__metadata_with_defaults__bin" \
    '.artifact' "$__homebrew__metadata_with_defaults__artifact"
  println "$__homebrew__metadata_with_defaults__out"
  @unlet __homebrew__metadata_with_defaults__ name bin artifact
}

: <<'FUN'
Prints the formula for the metadata $1, downloading from the base URL $2,
with the sums $3 as __homebrew__sums prints them.
FUN
__homebrew__render_formula() {
  @let "$1" __homebrew__render_formula__ name description homepage version license bin
  @let "$3" __homebrew__render_formula__ darwin_arm darwin_x86 linux_arm linux_x86

  sed \
    -e "s|{{class_name}}|$(__homebrew__ruby_class_name "$__homebrew__render_formula__name")|g" \
    -e "s|{{description}}|${__homebrew__render_formula__description}|g" \
    -e "s|{{homepage}}|${__homebrew__render_formula__homepage}|g" \
    -e "s|{{version}}|${__homebrew__render_formula__version}|g" \
    -e "s|{{license}}|${__homebrew__render_formula__license}|g" \
    -e "s|{{bin_name}}|${__homebrew__render_formula__bin}|g" \
    -e "s|{{darwin_arm_url}}|$(__homebrew__tarball_url "$1" "$2" "$__homebrew__TRIPLE_DARWIN_ARM")|g" \
    -e "s|{{darwin_arm_sha}}|${__homebrew__render_formula__darwin_arm}|g" \
    -e "s|{{darwin_x86_url}}|$(__homebrew__tarball_url "$1" "$2" "$__homebrew__TRIPLE_DARWIN_X86")|g" \
    -e "s|{{darwin_x86_sha}}|${__homebrew__render_formula__darwin_x86}|g" \
    -e "s|{{linux_arm_url}}|$(__homebrew__tarball_url "$1" "$2" "$__homebrew__TRIPLE_LINUX_ARM")|g" \
    -e "s|{{linux_arm_sha}}|${__homebrew__render_formula__linux_arm}|g" \
    -e "s|{{linux_x86_url}}|$(__homebrew__tarball_url "$1" "$2" "$__homebrew__TRIPLE_LINUX_X86")|g" \
    -e "s|{{linux_x86_sha}}|${__homebrew__render_formula__linux_x86}|g" \
    "${SHELLOPS_DIR}/lib/homebrew/formula.rb.tmpl"
  __homebrew__render_formula__status=$?
  @unlet __homebrew__render_formula__ name description homepage version license bin
  @unlet __homebrew__render_formula__ darwin_arm darwin_x86 linux_arm linux_x86
  return "$__homebrew__render_formula__status"
}

: <<'FUN'
Prints where the metadata's tarball for triple $3 is downloaded from: the
base URL $2 with the tarball's canonical name under it.

  __homebrew__tarball_url '{"artifact":"tool","version":"1.0.0"}' https://x/v1 x86_64-apple-darwin
    ->  https://x/v1/tool-1.0.0-x86_64-apple-darwin.tar.gz
FUN
__homebrew__tarball_url() {
  @let "$1" __homebrew__tarball_url__ artifact version

  printf '%s/%s\n' "$2" "$(tarball__artifact_name "$__homebrew__tarball_url__artifact" "$__homebrew__tarball_url__version" "$3")"
  @unlet __homebrew__tarball_url__ artifact version
}

: <<'FUN'
Prints the sum of the tarball named $1 at version $2 under $3 for each slot
the formula fills. Fails naming the first tarball that is not there, so no
formula is written with a sum missing.

  __homebrew__sums tool 1.2.0 ./dist
    ->  {"darwin_arm": "9a…", "darwin_x86": "3f…", "linux_arm": "c0…", "linux_x86": "e1…"}
FUN
__homebrew__sums() {
  __homebrew__sums__darwin_arm="$(__homebrew__sha256_for "$1" "$2" "$__homebrew__TRIPLE_DARWIN_ARM" "$3")" || return 1
  __homebrew__sums__darwin_x86="$(__homebrew__sha256_for "$1" "$2" "$__homebrew__TRIPLE_DARWIN_X86" "$3")" || return 1
  __homebrew__sums__linux_arm="$(__homebrew__sha256_for "$1" "$2" "$__homebrew__TRIPLE_LINUX_ARM" "$3")" || return 1
  __homebrew__sums__linux_x86="$(__homebrew__sha256_for "$1" "$2" "$__homebrew__TRIPLE_LINUX_X86" "$3")" || return 1

  @obj __homebrew__sums__out \
    '.darwin_arm' "$__homebrew__sums__darwin_arm" \
    '.darwin_x86' "$__homebrew__sums__darwin_x86" \
    '.linux_arm'  "$__homebrew__sums__linux_arm" \
    '.linux_x86'  "$__homebrew__sums__linux_x86"
  println "$__homebrew__sums__out"
}

__homebrew__sha256_for() {
  __homebrew__sha256_for__filename="$(tarball__artifact_name "$1" "$2" "$3")"
  __homebrew__sha256_for__filepath="${4}/${__homebrew__sha256_for__filename}"

  if [ ! -f "$__homebrew__sha256_for__filepath" ]; then
    error "tarball not found: ${__homebrew__sha256_for__filepath}"
    return 1
  fi

  sha256sum "$__homebrew__sha256_for__filepath" | cut -d' ' -f1
}

: <<'FUN'
Prints the Ruby class name a Homebrew formula takes, given the formula's name
in kebab or snake case.

  __homebrew__ruby_class_name "my-tool_x"  ->  MyToolX
FUN
__homebrew__ruby_class_name() {
  @split __homebrew__ruby_class_name__parts "$(println "$1" | tr -- '_' '-' | tr -- '-' '\n')"
  @map __homebrew__ruby_class_name__map_1 __homebrew__capitalize "$__homebrew__ruby_class_name__parts"
  @join __homebrew__ruby_class_name__out "$__homebrew__ruby_class_name__map_1" ""
  println "$__homebrew__ruby_class_name__out"
}

__homebrew__capitalize() {
  @unwrap __homebrew__capitalize__part "$1"
  __homebrew__capitalize__head="$(printf '%.1s' "$__homebrew__capitalize__part" | tr '[:lower:]' '[:upper:]')"
  @wrap __homebrew__capitalize__out "${__homebrew__capitalize__head}${__homebrew__capitalize__part#?}"
  println "$__homebrew__capitalize__out"
}

: <<'PUB_FUN'
Clones or updates a tap repository, writes a formula, commits, and pushes.

Parameters:
  tap_url    - git clone URL of the tap repo, credentials included when the
               push needs them; logs carry it with the credentials removed
  formula_rb - the formula content (string, typically from homebrew__generate_formula)
  name       - formula name (used for the filename and commit message)
  version    - version string (used in the commit message)
  options    - optional JSON object:
                 branch     - branch to push to (default: "main")
                 dir        - working directory for the clone (default: mktemp -d)
                 git_name   - committer name (default: "Blizz")
                 git_email  - committer email (default: "blizz@kernelle-soft.com")

  homebrew__update_tap "$tap_url" "$formula_rb" "insights" "1.2.0"
PUB_FUN
homebrew__update_tap() {
  __homebrew__update_tap__tap_url="$1"
  __homebrew__update_tap__formula_rb="$2"
  __homebrew__update_tap__name="$3"
  __homebrew__update_tap__version="$4"
  __homebrew__update_tap__options="${5:-}"
  [ -n "$__homebrew__update_tap__options" ] || @obj __homebrew__update_tap__options

  @let "$__homebrew__update_tap__options" __homebrew__update_tap__ branch dir git_name git_email
  @defined "$__homebrew__update_tap__branch" || __homebrew__update_tap__branch='main'
  @defined "$__homebrew__update_tap__git_name" || __homebrew__update_tap__git_name='Blizz'
  @defined "$__homebrew__update_tap__git_email" || __homebrew__update_tap__git_email='blizz@kernelle-soft.com'
  __homebrew__update_tap__workdir="$__homebrew__update_tap__dir"

  if ! @defined "$__homebrew__update_tap__workdir"; then
    __homebrew__update_tap__workdir="$(mktemp -d)"
  fi

  __homebrew__clone "$__homebrew__update_tap__tap_url" "$__homebrew__update_tap__workdir"
  __homebrew__checkout "$__homebrew__update_tap__workdir" "$__homebrew__update_tap__branch"
  __homebrew__configure_identity "$__homebrew__update_tap__workdir" "$__homebrew__update_tap__git_name" "$__homebrew__update_tap__git_email"
  __homebrew__write_formula "$__homebrew__update_tap__workdir" "$__homebrew__update_tap__name" "$__homebrew__update_tap__formula_rb"
  __homebrew__commit_and_push "$__homebrew__update_tap__workdir" "$__homebrew__update_tap__name" "$__homebrew__update_tap__version" "$__homebrew__update_tap__branch"
  __homebrew__update_tap__status=$?
  @unlet __homebrew__update_tap__ branch dir git_name git_email
  return "$__homebrew__update_tap__status"
}

__homebrew__clone() {
  if [ -d "$2/.git" ]; then
    log "updating tap at ${2}"
    git -C "$2" fetch origin
  else
    log "cloning tap from $(homebrew__redact_url "$1")"
    git clone "$1" "$2"
  fi
}

: <<'PUB_FUN'
Prints the URL $1 with any credentials before its host removed, the form a
log may carry.

  homebrew__redact_url https://oauth2:s3cret@git.example/org/tap.git  ->  https://git.example/org/tap.git
  homebrew__redact_url https://git.example/org/tap.git                ->  https://git.example/org/tap.git
PUB_FUN
homebrew__redact_url() {
  println "$1" | sed 's|^\([a-z][a-z0-9+.-]*://\)[^/@]*@|\1|'
}

__homebrew__checkout() {
  git -C "$1" checkout "$2"
  git -C "$1" reset --hard "origin/${2}"
}

__homebrew__configure_identity() {
  git -C "$1" config user.name "$2"
  git -C "$1" config user.email "$3"
}

__homebrew__write_formula() {
  __homebrew__write_formula__formula_dir="${1}/Formula"

  mkdir -p "$__homebrew__write_formula__formula_dir"
  echo "$3" > "${__homebrew__write_formula__formula_dir}/${2}.rb"
  log "wrote Formula/${2}.rb"
}

__homebrew__commit_and_push() {
  __homebrew__commit_and_push__workdir="$1"
  __homebrew__commit_and_push__name="$2"
  __homebrew__commit_and_push__version="$3"
  __homebrew__commit_and_push__branch="$4"

  git -C "$__homebrew__commit_and_push__workdir" add "Formula/${__homebrew__commit_and_push__name}.rb"

  if git -C "$__homebrew__commit_and_push__workdir" diff --cached --quiet; then
    log "no changes to Formula/${__homebrew__commit_and_push__name}.rb"
    return 0
  fi

  git -C "$__homebrew__commit_and_push__workdir" commit -m "${__homebrew__commit_and_push__name} ${__homebrew__commit_and_push__version}"
  git -C "$__homebrew__commit_and_push__workdir" push --force-with-lease origin "$__homebrew__commit_and_push__branch"
  log "pushed ${__homebrew__commit_and_push__name} ${__homebrew__commit_and_push__version} to tap"
}
