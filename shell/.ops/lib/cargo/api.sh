#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/rustup/api.sh" \
  "$SHELLOPS_DIR/lib/self/api.sh" \
  "$SHELLOPS_DIR/lib/toml/api.sh" \
  "$SHELLOPS_DIR/lib/versions/api.sh"

: <<'MODULE'
Cargo workspace and manifest management.

Provides introspection (metadata, crate lookup, version reading),
version management (set/sync versions), dependency helpers, and
workspace-aware publishing with topological ordering.
MODULE

# PUB_CONST: The file cargo steers a crate by; paths into a crate default to it.
CARGO_MANIFEST_FILE='Cargo.toml'

# CONST: One newline, which separates the ids in a list of ids kept as text.
__cargo__NL="
"

: <<'PUB_FUN'
Print true when $1 is a name cargo accepts for a binary target -- letters,
digits, hyphen and underscore only -- and false otherwise. The whole value is
judged at once, so a name with an embedded newline is rejected rather than
matched line by line. A leading hyphen is rejected too: cargo would read such
a name as a flag, not a target.

  cargo__bin_name_is_valid api-v2  ->  true
  cargo__bin_name_is_valid -api    ->  false
PUB_FUN
cargo__bin_name_is_valid() {
  case "$1" in
    '' | -* | *[!A-Za-z0-9_-]*) @false __cargo__bin_name_is_valid__out; println "$__cargo__bin_name_is_valid__out" ;;
    *) @true __cargo__bin_name_is_valid__out; println "$__cargo__bin_name_is_valid__out" ;;
  esac
}

: <<'FUN'
Returns the full cargo metadata JSON (no deps). Accepts an explicit
manifest path, or auto-detects from $PROJ by searching at, above, and
below the project root.

  json="$(cargo__metadata)"
  json="$(cargo__metadata "./backend/Cargo.toml")"
FUN
__cargo__resolve_manifest_path() {
  if [ $# -eq 0 ] || [ -z "${1-}" ]; then
    __cargo__find_nearest_manifest
    return $?
  fi

  __cargo__resolve_manifest_path__path="$1"

  case "$__cargo__resolve_manifest_path__path" in
    /*) ;;
    *)
      __cargo__resolve_manifest_path__base="${PROJ:-${PWD:-.}}"
      __cargo__resolve_manifest_path__path="$__cargo__resolve_manifest_path__base/$__cargo__resolve_manifest_path__path"
      ;;
  esac

  if [ ! -f "$__cargo__resolve_manifest_path__path" ]; then
    error "Cargo manifest not found: $__cargo__resolve_manifest_path__path"
    return 1
  fi

  echo "$__cargo__resolve_manifest_path__path"
}

cargo__metadata() {
  __cargo__metadata__manifest_path="$(__cargo__resolve_manifest_path "$@")" || return 1

  if ! command -v cargo >/dev/null 2>&1; then
    error "cargo not found on PATH; run 'ops install' to provision the rust toolchain (or rustup__prepare_cargo in-process) first"
    return 1
  fi

  if ! __cargo__metadata__output="$(
    cargo metadata --format-version 1 --no-deps --manifest-path "$__cargo__metadata__manifest_path" 2>&1
  )"; then
    __cargo__metadata__last_line="$(println "$__cargo__metadata__output" | tail -n1)"
    error "cargo metadata failed for ${__cargo__metadata__manifest_path}: ${__cargo__metadata__last_line}"
    return 1
  fi

  echo "$__cargo__metadata__output"
}

__cargo__find_nearest_manifest() {
  __cargo__FIND_NEAREST_PROJ="${PROJ:-${PWD:-.}}"

  if [ -f "$__cargo__FIND_NEAREST_PROJ/$CARGO_MANIFEST_FILE" ]; then
    echo "$__cargo__FIND_NEAREST_PROJ/$CARGO_MANIFEST_FILE"
    return
  fi

  __cargo__FIND_NEAREST_DIR="$__cargo__FIND_NEAREST_PROJ"
  while [ "$__cargo__FIND_NEAREST_DIR" != "/" ]; do
    __cargo__FIND_NEAREST_DIR="$(dirname "$__cargo__FIND_NEAREST_DIR")"
    if [ -f "$__cargo__FIND_NEAREST_DIR/$CARGO_MANIFEST_FILE" ]; then
      echo "$__cargo__FIND_NEAREST_DIR/$CARGO_MANIFEST_FILE"
      return
    fi
  done

  __cargo__FIND_NEAREST_FOUND="$(find "$__cargo__FIND_NEAREST_PROJ" -maxdepth 3 -name "$CARGO_MANIFEST_FILE" -not -path "*/target/*" -print -quit 2>/dev/null)"

  if @defined "$__cargo__FIND_NEAREST_FOUND"; then
    echo "$__cargo__FIND_NEAREST_FOUND"
    return
  fi

  error "no Cargo.toml found at or above $__cargo__FIND_NEAREST_PROJ"
  return 1
}

: <<'PUB_FUN'
Returns the workspace root directory.

  cargo__workspace_root
  cargo__workspace_root "./backend/Cargo.toml"
PUB_FUN
cargo__workspace_root() {
  __cargo__WS_ROOT_METADATA="$(cargo__metadata "$@")" || return 1
  @get __cargo__WS_ROOT_ROOT "$__cargo__WS_ROOT_METADATA" '.workspace_root'

  if ! @defined "$__cargo__WS_ROOT_ROOT"; then
    error "cargo metadata did not return workspace_root"
    return 1
  fi

  echo "$__cargo__WS_ROOT_ROOT"
}

: <<'PUB_FUN'
Returns the absolute path to the workspace root Cargo.toml.

  cargo__workspace_toml
  cargo__workspace_toml "./backend/Cargo.toml"
PUB_FUN
cargo__workspace_toml() {
  __cargo__WS_TOML_ROOT="$(cargo__workspace_root "$1")" || return 1
  echo "$__cargo__WS_TOML_ROOT/$CARGO_MANIFEST_FILE"
}

: <<'PUB_FUN'
Returns a struct array of the package names of every member of the workspace
rooted at the given manifest. `cargo -p NAME` resolves only against members, so
callers filter package names through this before handing them to cargo.

  cargo__workspace_member_names
  cargo__workspace_member_names "./engine/Cargo.toml"
PUB_FUN
cargo__workspace_member_names() {
  __cargo__MEMBER_NAMES_MANIFEST_PATH="${1:-}"

  __cargo__MEMBER_NAMES_METADATA="$(cargo__metadata "$__cargo__MEMBER_NAMES_MANIFEST_PATH")" || return 1
  @get __cargo__MEMBER_NAMES_PACKAGES "$__cargo__MEMBER_NAMES_METADATA" '.packages'
  @pluck __cargo__workspace_member_names__out "$__cargo__MEMBER_NAMES_PACKAGES" '.name'
  println "$__cargo__workspace_member_names__out"
}

: <<'PUB_FUN'
Finds the absolute path to a crate's directory by package name.

  cargo__find_crate "blizz"
  cargo__find_crate "blizz" "./backend/Cargo.toml"
PUB_FUN
cargo__find_crate() {
  __cargo__find_crate__name="$1"
  __cargo__find_crate__manifest_path="${2:-}"

  __cargo__find_crate__metadata="$(cargo__metadata "$__cargo__find_crate__manifest_path")"
  @get __cargo__find_crate__packages "$__cargo__find_crate__metadata" '.packages'
  @find __cargo__find_crate__pkg __cargo__match_crate_name "$__cargo__find_crate__packages" "$__cargo__find_crate__name"

  if ! @defined "$__cargo__find_crate__pkg"; then
    error "crate '$__cargo__find_crate__name' not found in workspace"
    return 1
  fi

  @get __cargo__find_crate__get_1 "$__cargo__find_crate__pkg" '.manifest_path'
  dirname "$__cargo__find_crate__get_1"
}

__cargo__match_crate_name() {
  __cargo__match_crate_name__element="$1"
  __cargo__match_crate_name__target="$2"
  @get __cargo__match_crate_name__get_2 "$__cargo__match_crate_name__element" '.name'
  [ "$__cargo__match_crate_name__get_2" = "$__cargo__match_crate_name__target" ]
}

: <<'PUB_FUN'
Echoes the cargo package name owning a file by walking up from the file's
directory to the nearest ancestor Cargo.toml that declares a [package] name.
The walk stops at $PROJ so it never escapes the repo. Echoes "" when no
owning manifest is found.

  $1  file path, relative to $PROJ

  cargo__package_for_file "engine/cache/src/lib.rs"  # -> "opcache"
PUB_FUN
cargo__package_for_file() {
  __cargo__package_for_file__dir="$(dirname "$PROJ/$1")"

  while :; do
    __cargo__package_for_file__manifest="$__cargo__package_for_file__dir/$CARGO_MANIFEST_FILE"
    if [ -f "$__cargo__package_for_file__manifest" ]; then
      __cargo__package_for_file__name="$(toml__get "$__cargo__package_for_file__manifest" package name)"
      if @defined "$__cargo__package_for_file__name"; then
        printf '%s' "$__cargo__package_for_file__name"
        return 0
      fi
    fi

    if [ "$__cargo__package_for_file__dir" = "$PROJ" ] || [ "$__cargo__package_for_file__dir" = "/" ]; then
      break
    fi
    __cargo__package_for_file__dir="$(dirname "$__cargo__package_for_file__dir")"
  done

  printf ''
}

: <<'PUB_FUN'
Gets the version of a crate by package name. If no name is given,
returns the version of the first package in the workspace.

  cargo__get_crate_version "blizz"
  cargo__get_crate_version "blizz" "./backend/Cargo.toml"
PUB_FUN
cargo__get_crate_version() {
  __cargo__GET_VER_NAME="${1:-}"
  __cargo__GET_VER_MANIFEST_PATH="${2:-}"

  __cargo__GET_VER_METADATA="$(cargo__metadata "$__cargo__GET_VER_MANIFEST_PATH")"
  @get __cargo__GET_VER_PACKAGES "$__cargo__GET_VER_METADATA" '.packages'

  if [ -z "$__cargo__GET_VER_NAME" ]; then
    @get __cargo__get_crate_version__out "$__cargo__GET_VER_METADATA" '.packages[0].version'
    println "$__cargo__get_crate_version__out"
    return
  fi

  @find __cargo__GET_VER_PKG __cargo__match_crate_name "$__cargo__GET_VER_PACKAGES" "$__cargo__GET_VER_NAME"

  if ! @defined "$__cargo__GET_VER_PKG"; then
    error "crate '$__cargo__GET_VER_NAME' not found in workspace"
    return 1
  fi

  @get __cargo__get_crate_version__out "$__cargo__GET_VER_PKG" '.version'
  println "$__cargo__get_crate_version__out"
}

: <<'PUB_FUN'
Sets the version for a specific crate and updates the lockfile. Detects
whether the crate uses workspace-inherited versioning and updates the
correct Cargo.toml accordingly.

  cargo__set_crate_version "mypackage" "1.2.3"
  cargo__set_crate_version "mypackage" "1.2.3" "./backend/Cargo.toml"
PUB_FUN
cargo__set_crate_version() {
  __cargo__SET_VER_PACKAGE_NAME="$1"
  __cargo__SET_VER_VERSION="$2"
  __cargo__SET_VER_MANIFEST_PATH="${3:-}"

  __cargo__SET_VER_CRATE_DIR="$(cargo__find_crate "$__cargo__SET_VER_PACKAGE_NAME" "$__cargo__SET_VER_MANIFEST_PATH")"
  __cargo__SET_VER_CARGO_TOML="${__cargo__SET_VER_CRATE_DIR}/$CARGO_MANIFEST_FILE"

  if __cargo__uses_workspace_version "$__cargo__SET_VER_CARGO_TOML"; then
    cargo__set_workspace_version "$__cargo__SET_VER_VERSION" "$__cargo__SET_VER_MANIFEST_PATH"
    return
  fi

  __cargo__SET_VER_OLD_VERSION="$(cargo__get_crate_version "$__cargo__SET_VER_PACKAGE_NAME" "$__cargo__SET_VER_MANIFEST_PATH")"

  if [ "$__cargo__SET_VER_OLD_VERSION" = "$__cargo__SET_VER_VERSION" ]; then
    log "already at version '$__cargo__SET_VER_VERSION'"
    return 0
  fi

  toml__replace "$__cargo__SET_VER_CARGO_TOML" "package" "version" "$__cargo__SET_VER_OLD_VERSION" "$__cargo__SET_VER_VERSION"
  __cargo__update_lockfile "$__cargo__SET_VER_CARGO_TOML" "$__cargo__SET_VER_PACKAGE_NAME" "$__cargo__SET_VER_VERSION"
  log "Updated ${__cargo__SET_VER_CARGO_TOML} to '$__cargo__SET_VER_VERSION'"
}

__cargo__update_lockfile() {
  __cargo__UPDATE_LOCK_MANIFEST="$1"
  __cargo__UPDATE_LOCK_PACKAGE="$2"
  __cargo__UPDATE_LOCK_VERSION="$3"
  cargo update --manifest-path "$__cargo__UPDATE_LOCK_MANIFEST" --package "$__cargo__UPDATE_LOCK_PACKAGE" --precise "$__cargo__UPDATE_LOCK_VERSION"
}

: <<'PUB_FUN'
Sets the workspace-level version directly (in [workspace.package]).

  cargo__set_workspace_version "1.2.3"
  cargo__set_workspace_version "1.2.3" "./backend/Cargo.toml"
PUB_FUN
cargo__set_workspace_version() {
  __cargo__SET_WS_VER_VERSION="$1"
  __cargo__SET_WS_VER_MANIFEST_PATH="${2:-}"

  __cargo__SET_WS_VER_WORKSPACE_TOML="$(cargo__workspace_toml "$__cargo__SET_WS_VER_MANIFEST_PATH")" || return 1
  __cargo__SET_WS_VER_OLD_VERSION="$(__cargo__read_workspace_package_version "$__cargo__SET_WS_VER_WORKSPACE_TOML")"

  if [ "$__cargo__SET_WS_VER_OLD_VERSION" = "$__cargo__SET_WS_VER_VERSION" ]; then
    log "workspace already at version '$__cargo__SET_WS_VER_VERSION'"
    return 0
  fi

  toml__replace "$__cargo__SET_WS_VER_WORKSPACE_TOML" "workspace.package" "version" "$__cargo__SET_WS_VER_OLD_VERSION" "$__cargo__SET_WS_VER_VERSION"
  log "Updated workspace version in ${__cargo__SET_WS_VER_WORKSPACE_TOML} to '$__cargo__SET_WS_VER_VERSION'"

  cargo__workspace_sync_versions "$__cargo__SET_WS_VER_VERSION" "$__cargo__SET_WS_VER_MANIFEST_PATH"
}

__cargo__uses_workspace_version() {
  __cargo__USES_WS_VER_CARGO_TOML="$1"
  grep -q 'version\.workspace\s*=\s*true' "$__cargo__USES_WS_VER_CARGO_TOML" 2>/dev/null
}

__cargo__read_workspace_package_version() {
  __cargo__READ_WS_VER_VERSION="$(toml__get "$1" "workspace.package" "version")"
  echo "${__cargo__READ_WS_VER_VERSION:-0.0.0}"
}

: <<'PUB_FUN'
Prints the struct boolean for whether <dep_name> appears as a key under any
[*dependencies*] section of <cargo_toml>.

  if @is_true "$(cargo__has_dep "Cargo.toml" "serde")"; then ... fi
PUB_FUN
cargo__has_dep() {
  @succeeds __cargo__has_dep__out awk -f "$SHELLOPS_DIR/lib/cargo/has_dep.awk" -v dep="$2" "$1"
  println "$__cargo__has_dep__out"
}

: <<'PUB_FUN'
For an inline table dep with path = ..., ensures version = "=<ver>" is
present and correct. Scopes to any [*dependencies*] section.

  cargo__set_dep_version "Cargo.toml" "blizz-derive" "2.0.1"
PUB_FUN
cargo__set_dep_version() {
  __cargo__SET_DEP_VER_FILE="$1"
  __cargo__SET_DEP_VER_DEP_NAME="$2"
  __cargo__SET_DEP_VER_VERSION="$3"
  __cargo__set_dep_field_in_section "$__cargo__SET_DEP_VER_FILE" "$__cargo__SET_DEP_VER_DEP_NAME" "version" "\"=${__cargo__SET_DEP_VER_VERSION}\""
}

: <<'PUB_FUN'
Same as cargo__set_dep_version but scoped to [workspace.dependencies] only.

  cargo__set_workspace_dep_version "Cargo.toml" "blizz-derive" "2.0.1"
PUB_FUN
cargo__set_workspace_dep_version() {
  __cargo__SET_WS_DEP_VER_FILE="$1"
  __cargo__SET_WS_DEP_VER_DEP_NAME="$2"
  __cargo__SET_WS_DEP_VER_VERSION="$3"
  __cargo__set_dep_field_in_section "$__cargo__SET_WS_DEP_VER_FILE" "$__cargo__SET_WS_DEP_VER_DEP_NAME" "version" "\"=${__cargo__SET_WS_DEP_VER_VERSION}\"" "workspace.dependencies"
}

__cargo__set_dep_field_in_section() {
  __cargo__SET_FIELD_FILE="$1"
  __cargo__SET_FIELD_DEP_NAME="$2"
  __cargo__SET_FIELD_FIELD="$3"
  __cargo__SET_FIELD_VALUE="$4"
  __cargo__SET_FIELD_SECTION_PATTERN="${5:-dependencies}"
  __cargo__SET_FIELD_TEMP_FILE="${__cargo__SET_FIELD_FILE}.tmp"
  __cargo__SET_FIELD_IN_SECTION=false

  while IFS= read -r __cargo__SET_FIELD_LINE; do
    if [ "$__cargo__SET_FIELD_SECTION_PATTERN" = "workspace.dependencies" ]; then
      case "$__cargo__SET_FIELD_LINE" in
        "[workspace.dependencies]")
          __cargo__SET_FIELD_IN_SECTION=true
          ;;
        \[*)
          __cargo__SET_FIELD_IN_SECTION=false
          ;;
      esac
    else
      case "$__cargo__SET_FIELD_LINE" in
        \[*dependencies*\]*)
          __cargo__SET_FIELD_IN_SECTION=true
          ;;
        \[*)
          __cargo__SET_FIELD_IN_SECTION=false
          ;;
      esac
    fi

    if $__cargo__SET_FIELD_IN_SECTION \
      && println "$__cargo__SET_FIELD_LINE" | grep -qE "^[[:space:]]*\"?${__cargo__SET_FIELD_DEP_NAME}\"?[[:space:]]*=" \
      && println "$__cargo__SET_FIELD_LINE" | grep -q "path"; then
      __cargo__SET_FIELD_LINE="$(toml__inline_set "$__cargo__SET_FIELD_LINE" "$__cargo__SET_FIELD_FIELD" "$__cargo__SET_FIELD_VALUE")"
    fi

    echo "$__cargo__SET_FIELD_LINE"
  done < "$__cargo__SET_FIELD_FILE" > "$__cargo__SET_FIELD_TEMP_FILE"
  mv "$__cargo__SET_FIELD_TEMP_FILE" "$__cargo__SET_FIELD_FILE"
}

: <<'PUB_FUN'
Injects registry = "<name>" into all internal path dep specs across a workspace.
Operates on the files in-place — intended for use on a disposable temp copy.

  cargo__workspace_inject_dep_registry "internal" "./Cargo.toml"
PUB_FUN
cargo__workspace_inject_dep_registry() {
  __cargo__INJECT_REG_REGISTRY="$1"
  __cargo__INJECT_REG_MANIFEST_PATH="${2:-}"
  __cargo__INJECT_REG_INTERNAL_DEPS="$(cargo__workspace_get_internal_deps "$__cargo__INJECT_REG_MANIFEST_PATH")"

  @foreach __cargo__inject_one_dep_registry "$__cargo__INJECT_REG_INTERNAL_DEPS" "$__cargo__INJECT_REG_REGISTRY"

  log "Injected registry = \"${__cargo__INJECT_REG_REGISTRY}\" into internal dep specs"
}

__cargo__inject_one_dep_registry() {
  __cargo__INJECT_ONE_REG_ELEMENT="$1"
  __cargo__INJECT_ONE_REG_REGISTRY="$2"
  @let "$__cargo__INJECT_ONE_REG_ELEMENT" __cargo__inject_one_dep_registry__ consumer dep
  __cargo__INJECT_ONE_REG_CONSUMER="$__cargo__inject_one_dep_registry__consumer"
  __cargo__INJECT_ONE_REG_DEP="$__cargo__inject_one_dep_registry__dep"
  @unlet __cargo__inject_one_dep_registry__ consumer dep
  __cargo__set_dep_field_in_section "$__cargo__INJECT_ONE_REG_CONSUMER" "$__cargo__INJECT_ONE_REG_DEP" "registry" "\"${__cargo__INJECT_ONE_REG_REGISTRY}\""
}

: <<'PUB_FUN'
Returns a JSON array of internal path dependencies in the workspace.
Each entry is: { "consumer": "<manifest_path>", "dep": "<package_name>" }

Only includes deps where both consumer and dep are workspace members.

  cargo__workspace_get_internal_deps
  cargo__workspace_get_internal_deps "./backend/Cargo.toml"
PUB_FUN
cargo__workspace_get_internal_deps() {
  __cargo__GET_INT_DEPS_MANIFEST_PATH="${1:-}"

  __cargo__GET_INT_DEPS_METADATA="$(cargo__metadata "$__cargo__GET_INT_DEPS_MANIFEST_PATH")"
  @run_awk __cargo__workspace_get_internal_deps__out "$SHELLOPS_DIR/lib/cargo/get_internal_deps.awk" "$__cargo__GET_INT_DEPS_METADATA" || return 1
  println "$__cargo__workspace_get_internal_deps__out"
}

: <<'PUB_FUN'
Ensures every internal path dep has version = "=<version>".
Handles both [workspace.dependencies] entries and inline path deps.

  cargo__workspace_sync_versions "1.2.3"
  cargo__workspace_sync_versions "1.2.3" "./backend/Cargo.toml"
PUB_FUN
cargo__workspace_sync_versions() {
  __cargo__SYNC_VER_VERSION="$1"
  __cargo__SYNC_VER_MANIFEST_PATH="${2:-}"

  __cargo__SYNC_VER_INTERNAL_DEPS="$(cargo__workspace_get_internal_deps "$__cargo__SYNC_VER_MANIFEST_PATH")"
  __cargo__SYNC_VER_WORKSPACE_TOML="$(cargo__workspace_toml "$__cargo__SYNC_VER_MANIFEST_PATH")" || return 1

  __cargo__sync_workspace_deps_section "$__cargo__SYNC_VER_WORKSPACE_TOML" "$__cargo__SYNC_VER_VERSION" "$__cargo__SYNC_VER_MANIFEST_PATH"
  @foreach __cargo__sync_one_dep "$__cargo__SYNC_VER_INTERNAL_DEPS" "$__cargo__SYNC_VER_VERSION"

  log "Internal dep versions synced to '=${__cargo__SYNC_VER_VERSION}'"
}

__cargo__sync_one_dep() {
  __cargo__sync_one_dep__element="$1"
  __cargo__sync_one_dep__version="$2"
  @let "$__cargo__sync_one_dep__element" __cargo__sync_one_dep__ consumer dep
  __cargo__sync_dep_version_in_file "$__cargo__sync_one_dep__consumer" "$__cargo__sync_one_dep__dep" "$__cargo__sync_one_dep__version"
  __cargo__sync_one_dep__status=$?
  @unlet __cargo__sync_one_dep__ consumer dep
  return "$__cargo__sync_one_dep__status"
}

: <<'PUB_FUN'
Returns the manifests a workspace version sync writes, as an array of paths:
the workspace Cargo.toml plus every member manifest that pins an internal
path dep. A commit carrying a workspace sync names exactly this set.

  cargo__workspace_sync_manifests
  cargo__workspace_sync_manifests "./backend/Cargo.toml"
PUB_FUN
cargo__workspace_sync_manifests() {
  __cargo__SYNC_MANIFESTS_WORKSPACE_TOML="$(cargo__workspace_toml "${1:-}")" || return 1
  __cargo__SYNC_MANIFESTS_INTERNAL_DEPS="$(cargo__workspace_get_internal_deps "${1:-}")" || return 1
  @pluck __cargo__SYNC_MANIFESTS_CONSUMERS "$__cargo__SYNC_MANIFESTS_INTERNAL_DEPS" '.consumer'

  @arr __cargo__workspace_sync_manifests__arr_3 "$__cargo__SYNC_MANIFESTS_WORKSPACE_TOML"
  @concat __cargo__workspace_sync_manifests__concat_4 \
    "$__cargo__workspace_sync_manifests__arr_3" \
    "$__cargo__SYNC_MANIFESTS_CONSUMERS"
  @unique __cargo__workspace_sync_manifests__out "$__cargo__workspace_sync_manifests__concat_4"
  println "$__cargo__workspace_sync_manifests__out"
}

__cargo__sync_workspace_deps_section() {
  __cargo__SYNC_WS_DEPS_CARGO_TOML="$1"
  __cargo__SYNC_WS_DEPS_VERSION="$2"
  __cargo__SYNC_WS_DEPS_MANIFEST_PATH="${3:-}"

  [ ! -f "$__cargo__SYNC_WS_DEPS_CARGO_TOML" ] && return

  __cargo__SYNC_WS_DEPS_INTERNAL_DEPS="$(cargo__workspace_get_internal_deps "$__cargo__SYNC_WS_DEPS_MANIFEST_PATH")"
  @foreach __cargo__sync_ws_dep_entry "$__cargo__SYNC_WS_DEPS_INTERNAL_DEPS" "$__cargo__SYNC_WS_DEPS_CARGO_TOML" "$__cargo__SYNC_WS_DEPS_VERSION"
}

__cargo__sync_ws_dep_entry() {
  __cargo__sync_ws_dep_entry__element="$1"
  __cargo__sync_ws_dep_entry__cargo_toml="$2"
  __cargo__sync_ws_dep_entry__version="$3"
  @get __cargo__sync_ws_dep_entry__dep_name "$__cargo__sync_ws_dep_entry__element" '.dep'
  cargo__set_workspace_dep_version "$__cargo__sync_ws_dep_entry__cargo_toml" "$__cargo__sync_ws_dep_entry__dep_name" "$__cargo__sync_ws_dep_entry__version"
}

__cargo__sync_dep_version_in_file() {
  __cargo__SYNC_DEP_FILE_CARGO_TOML="$1"
  __cargo__SYNC_DEP_FILE_DEP_NAME="$2"
  __cargo__SYNC_DEP_FILE_VERSION="$3"

  [ ! -f "$__cargo__SYNC_DEP_FILE_CARGO_TOML" ] && return
  @is_true "$(cargo__has_dep "$__cargo__SYNC_DEP_FILE_CARGO_TOML" "$__cargo__SYNC_DEP_FILE_DEP_NAME")" || return 0
  cargo__set_dep_version "$__cargo__SYNC_DEP_FILE_CARGO_TOML" "$__cargo__SYNC_DEP_FILE_DEP_NAME" "$__cargo__SYNC_DEP_FILE_VERSION"
}

: <<'PUB_FUN'
Returns the number of publishable workspace members (those without
publish = false or publish = []).

  cargo__workspace_get_publishable_count
  cargo__workspace_get_publishable_count "./backend/Cargo.toml"
PUB_FUN
cargo__workspace_get_publishable_count() {
  __cargo__PUB_COUNT_MANIFEST_PATH="${1:-}"

  __cargo__PUB_COUNT_METADATA="$(cargo__metadata "$__cargo__PUB_COUNT_MANIFEST_PATH")"
  @len __cargo__workspace_get_publishable_count__out "$(__cargo__publishable_packages "$__cargo__PUB_COUNT_METADATA")"
  println "$__cargo__workspace_get_publishable_count__out"
}

: <<'FUN'
Prints the packages of the cargo metadata $1 that are workspace members and
may be published, as a struct array in the order cargo lists them. A package
may not be published when its manifest says publish = false or publish = [].

  __cargo__publishable_packages "$metadata"  ->  [{"name":"blizz","id":"...",...}]
FUN
__cargo__publishable_packages() {
  @arr __cargo__publishable_packages__none
  @get __cargo__publishable_packages__members "$1" '.workspace_members' "$__cargo__publishable_packages__none"
  @join __cargo__publishable_packages__ids "$__cargo__publishable_packages__members" "$__cargo__NL"
  @get __cargo__publishable_packages__packages "$1" '.packages' "$__cargo__publishable_packages__none"

  @filter __cargo__publishable_packages__out \
    "$__cargo__publishable_packages__packages" \
    __cargo__is_publishable_member \
    "$__cargo__publishable_packages__ids"
  println "$__cargo__publishable_packages__out"
}

: <<'FUN'
A predicate for @filter: answers true in the variable $1 when the package $3
is a workspace member and may be published, and false otherwise. The ids of
the workspace members are $4, one on each line.
FUN
__cargo__is_publishable_member() {
  @get __cargo__is_publishable_member__id "$3" '.id' ''

  case "$__cargo__NL$4$__cargo__NL" in
    # structs-lint: allow -- whether an id is among ids kept one on each line, in plain text
    *"$__cargo__NL$__cargo__is_publishable_member__id$__cargo__NL"*) __cargo__may_publish "$1" "$3" ;;
    *) @false "$1" ;;
  esac
}

: <<'FUN'
Answers in the variable $1 whether the manifest of the package $2 lets it be
published: false when its publish is false, the empty array or the array
that holds the one string "false", and true otherwise.
FUN
__cargo__may_publish() {
  @typeof __cargo__may_publish__kind "$2" '.publish'

  case "$__cargo__may_publish__kind" in
    boolean) __cargo__publish_flag_allows "$1" "$2" ;;
    array) __cargo__publish_list_allows "$1" "$2" ;;
    *) @true "$1" ;;
  esac
}

: <<'FUN'
Answers in the variable $1 whether the boolean publish of the package $2 is
true.
FUN
__cargo__publish_flag_allows() {
  @get __cargo__publish_flag_allows__flag "$2" '.publish'
  @equals "$1" "$__cargo__publish_flag_allows__flag" true
}

: <<'FUN'
Answers in the variable $1 whether the publish list of the package $2 names
a registry: false for the empty list and for the list that holds the one
string "false", and true otherwise.
FUN
__cargo__publish_list_allows() {
  @get __cargo__publish_list_allows__list "$2" '.publish'
  @len __cargo__publish_list_allows__count "$__cargo__publish_list_allows__list"
  @get __cargo__publish_list_allows__first "$__cargo__publish_list_allows__list" '.[0]' ''

  if [ "$__cargo__publish_list_allows__count" -eq 0 ]; then
    @false "$1"
  elif [ "$__cargo__publish_list_allows__count" -eq 1 ] && [ "$__cargo__publish_list_allows__first" = false ]; then
    @false "$1"
  else
    @true "$1"
  fi
}

: <<'PUB_FUN'
Returns a JSON array of publishable workspace member package names.
Excludes members that opt out via `publish = false` or `publish = []`.

Order is whatever cargo metadata returns — `cargo publish --workspace`
resolves topological order itself, so callers should not depend on it.

  cargo__workspace_get_publishable_members
  cargo__workspace_get_publishable_members "./backend/Cargo.toml"
PUB_FUN
cargo__workspace_get_publishable_members() {
  __cargo__PUB_MEMBERS_MANIFEST_PATH="${1:-}"
  __cargo__PUB_MEMBERS_METADATA="$(cargo__metadata "$__cargo__PUB_MEMBERS_MANIFEST_PATH")"
  @pluck __cargo__workspace_get_publishable_members__out "$(__cargo__publishable_packages "$__cargo__PUB_MEMBERS_METADATA")" '.name'
  println "$__cargo__workspace_get_publishable_members__out"
}

: <<'PUB_FUN'
Validates that all internal path deps have the correct version pin.
Returns 0 if valid, 1 if violations found (prints errors to stderr).

  cargo__workspace_validate_versions "1.2.3"
  cargo__workspace_validate_versions "1.2.3" "./backend/Cargo.toml"
PUB_FUN
cargo__workspace_validate_versions() {
  __cargo__VALIDATE_VER_EXPECTED_VERSION="$1"
  __cargo__VALIDATE_VER_MANIFEST_PATH="${2:-}"

  __cargo__VALIDATE_VER_INTERNAL_DEPS="$(cargo__workspace_get_internal_deps "$__cargo__VALIDATE_VER_MANIFEST_PATH")"

  __cargo__CARGO_VALIDATE_VIOLATIONS=0
  @foreach __cargo__validate_one_dep "$__cargo__VALIDATE_VER_INTERNAL_DEPS" "$__cargo__VALIDATE_VER_EXPECTED_VERSION"

  if [ "$__cargo__CARGO_VALIDATE_VIOLATIONS" -gt 0 ]; then
    hint "run \`shell/action cargo sync-version --workspace ${__cargo__VALIDATE_VER_EXPECTED_VERSION}\`"
    unset __cargo__CARGO_VALIDATE_VIOLATIONS
    return 1
  fi
  unset __cargo__CARGO_VALIDATE_VIOLATIONS
  return 0
}

__cargo__validate_one_dep() {
  __cargo__VALIDATE_ONE_ELEMENT="$1"
  __cargo__VALIDATE_ONE_EXPECTED_VERSION="$2"
  @let "$__cargo__VALIDATE_ONE_ELEMENT" __cargo__validate_one_dep__ consumer dep
  __cargo__VALIDATE_ONE_CONSUMER="$__cargo__validate_one_dep__consumer"
  __cargo__VALIDATE_ONE_DEP="$__cargo__validate_one_dep__dep"
  @unlet __cargo__validate_one_dep__ consumer dep

  __cargo__VALIDATE_ONE_CHECK_FILE="$__cargo__VALIDATE_ONE_CONSUMER"
  if grep -qE "${__cargo__VALIDATE_ONE_DEP}\.workspace[[:space:]]*=[[:space:]]*true|${__cargo__VALIDATE_ONE_DEP}[[:space:]]*=.*workspace[[:space:]]*=[[:space:]]*true" "$__cargo__VALIDATE_ONE_CONSUMER" 2>/dev/null; then
    __cargo__VALIDATE_ONE_WS_ROOT="$(dirname "$__cargo__VALIDATE_ONE_CONSUMER")"
    while [ "$__cargo__VALIDATE_ONE_WS_ROOT" != "/" ]; do
      if grep -q '^\[workspace\]' "${__cargo__VALIDATE_ONE_WS_ROOT}/$CARGO_MANIFEST_FILE" 2>/dev/null; then
        __cargo__VALIDATE_ONE_CHECK_FILE="${__cargo__VALIDATE_ONE_WS_ROOT}/$CARGO_MANIFEST_FILE"
        break
      fi
      __cargo__VALIDATE_ONE_WS_ROOT="$(dirname "$__cargo__VALIDATE_ONE_WS_ROOT")"
    done
  fi

  if grep -q "${__cargo__VALIDATE_ONE_DEP}.*version[[:space:]]*=[[:space:]]*\"=${__cargo__VALIDATE_ONE_EXPECTED_VERSION}\"" "$__cargo__VALIDATE_ONE_CHECK_FILE" 2>/dev/null; then
    return 0
  fi

  __cargo__VALIDATE_ONE_FOUND_VERSION="(missing)"
  __cargo__VALIDATE_ONE_EXISTING="$(grep "${__cargo__VALIDATE_ONE_DEP}.*version" "$__cargo__VALIDATE_ONE_CHECK_FILE" 2>/dev/null | sed -n 's/.*version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)" || true
  if @defined "$__cargo__VALIDATE_ONE_EXISTING"; then
    __cargo__VALIDATE_ONE_FOUND_VERSION="$__cargo__VALIDATE_ONE_EXISTING"
  fi

  error "internal dep '$__cargo__VALIDATE_ONE_DEP' in $__cargo__VALIDATE_ONE_CHECK_FILE has stale version spec"
  log "  found:    version = \"${__cargo__VALIDATE_ONE_FOUND_VERSION}\""
  log "  expected: version = \"=${__cargo__VALIDATE_ONE_EXPECTED_VERSION}\""
  __cargo__CARGO_VALIDATE_VIOLATIONS=$(( __cargo__CARGO_VALIDATE_VIOLATIONS + 1 ))
}

: <<'PUB_FUN'
Publishes all workspace members via `cargo publish --workspace` (Cargo 1.90+).
A single crate takes the same path as a workspace. Internal dep versions are
validated first, and already-published members are excluded, so a retry after
a partial failure picks up where it stopped.

With --confidence-gate, every version goes to --internal-registry from a
sandbox copy, with --no-verify, when CARGO_REGISTRIES_<REGISTRY>_TOKEN is set;
versions at or above the gate go to crates.io as well, verified in full.
Without it, publishes go to --registry or the default.

The job's own directories under the workspace -- the cargo and rustup homes
and the ops cache -- never fail cargo's clean-tree check or ride along in
the crate.

Usage:
  cargo__workspace_publish "1.2.3" [--registry <name>] [--dry-run] \
    [--confidence-gate <ch>] [--internal-registry <name>]
PUB_FUN
cargo__workspace_publish() {
  __cargo__PUBLISH_VERSION="$1"; shift
  __cargo__CARGO_PUBLISH_REGISTRY=""
  __cargo__workspace_publish__CARGO_PUBLISH_DRY_RUN=""
  __cargo__CARGO_PUBLISH_MANIFEST=""
  __cargo__workspace_publish__CARGO_PUBLISH_CONFIDENCE_GATE=""
  __cargo__workspace_publish__CARGO_PUBLISH_INTERNAL_REGISTRY="internal"
  __cargo__CARGO_PUBLISH_NO_VERIFY=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --registry) __cargo__CARGO_PUBLISH_REGISTRY="$2"; shift ;;
      --dry-run) __cargo__workspace_publish__CARGO_PUBLISH_DRY_RUN="--dry-run" ;;
      --cargo-path) __cargo__CARGO_PUBLISH_MANIFEST="$2"; shift ;;
      --confidence-gate) __cargo__workspace_publish__CARGO_PUBLISH_CONFIDENCE_GATE="$2"; shift ;;
      --internal-registry) __cargo__workspace_publish__CARGO_PUBLISH_INTERNAL_REGISTRY="$2"; shift ;;
    esac
    shift
  done

  if ! cargo__workspace_validate_versions "$__cargo__PUBLISH_VERSION" "$__cargo__CARGO_PUBLISH_MANIFEST"; then
    error "Internal dep version validation failed. Aborting publish."
    return 1
  fi

  __cargo__exclude_job_homes "$(cargo__workspace_root "$__cargo__CARGO_PUBLISH_MANIFEST")"

  if [ -n "$__cargo__workspace_publish__CARGO_PUBLISH_CONFIDENCE_GATE" ] && [ -z "$__cargo__CARGO_PUBLISH_REGISTRY" ]; then
    __cargo__dual_publish "$__cargo__PUBLISH_VERSION"
  else
    __cargo__run_workspace_publish "$__cargo__PUBLISH_VERSION"
  fi

  unset __cargo__CARGO_PUBLISH_REGISTRY __cargo__workspace_publish__CARGO_PUBLISH_DRY_RUN __cargo__CARGO_PUBLISH_MANIFEST \
    __cargo__workspace_publish__CARGO_PUBLISH_CONFIDENCE_GATE __cargo__workspace_publish__CARGO_PUBLISH_INTERNAL_REGISTRY __cargo__CARGO_PUBLISH_NO_VERIFY \
    __cargo__CARGO_PUBLISH_EXCLUDE_ARGS __cargo__CARGO_PUBLISH_PENDING
}

: <<'FUN'
Prints <path> relative to <root> when it lies under it, nothing otherwise.

  __cargo__relative_under /p /p/.cargo        ->  .cargo
  __cargo__relative_under /p /home/me/.cargo  ->  (nothing)

args:
  $1  The root
  $2  The path
FUN
__cargo__relative_under() {
  case "$2" in
    "$1"/*) printf '%s\n' "${2#"$1"/}" ;;
  esac
}

: <<'FUN'
Prints the directories a job keeps its own toolchain and tool cache in when
they sit under <root>, one path per line relative to it: the cargo home, the
rustup home and the ops cache. A home outside the root prints nothing, since
cargo never sees it there.

  CARGO_HOME=/p/.cargo RUSTUP_HOME=/p/.rustup PROJ=/p __cargo__job_homes_under /p
    ->  .cargo
        .rustup
        .ops/cache

args:
  $1  The workspace root
FUN
__cargo__job_homes_under() {
  __cargo__job_homes_under__root="$1"
  __cargo__relative_under "$__cargo__job_homes_under__root" "$(rustup__cargo_home)"
  __cargo__relative_under "$__cargo__job_homes_under__root" "$(rustup__home)"
  __cargo__relative_under "$__cargo__job_homes_under__root" "${PROJ:-$__cargo__job_homes_under__root}/.ops/cache"
}

: <<'FUN'
Keeps the job's own directories out of cargo's view of the crate: each path
__cargo__job_homes_under prints goes into the repository's exclude file, which
cargo reads for both its clean-tree check and the files it packages. A
toolchain the job installed into the tree then neither fails the check nor
rides along in the crate. Each path is written once, and a root outside any
repository is left alone.

args:
  $1  The workspace root
FUN
__cargo__exclude_job_homes() {
  __cargo__exclude_job_homes__file="$(git__info_exclude "$1")"
  @defined "$__cargo__exclude_job_homes__file" || return 0

  mkdir -p "$(dirname "$__cargo__exclude_job_homes__file")"
  __cargo__job_homes_under "$1" | {
    while IFS= read -r __cargo__exclude_job_homes__home; do
      __cargo__exclude_one_home "$__cargo__exclude_job_homes__file" "$__cargo__exclude_job_homes__home"
    done
  }
}

: <<'FUN'
Appends the exclude line for one directory to the exclude file <file>,
anchored at the root and matching the directory alone, unless the line is
there already.

args:
  $1  The exclude file
  $2  The directory, relative to the root
FUN
__cargo__exclude_one_home() {
  __cargo__exclude_one_home__line="/$2/"
  if ! grep -qxF "$__cargo__exclude_one_home__line" "$1" 2>/dev/null; then
    println "$__cargo__exclude_one_home__line" >> "$1"
  fi
}

: <<'FUN'
Prints the tar invocation that copies the tree at <root> for a sandboxed
publish, as a struct array of arguments: the build output, the repository and
the job's own directories under the root are left behind, so the archive
holds the crate alone.

  CARGO_HOME=/p/.cargo __cargo__tar_argv_without_job_homes /p
    ->  ["-C","/p","--exclude=target","--exclude=.git","--exclude=./.cargo","-cf","-","."]

args:
  $1  The workspace root
FUN
__cargo__tar_argv_without_job_homes() {
  __cargo__job_homes_under "$1" | {
    @arr __cargo__tar_argv_without_job_homes__argv -C "$1" --exclude=target --exclude=.git
    while IFS= read -r __cargo__tar_argv_without_job_homes__home; do
      @push __cargo__tar_argv_without_job_homes__argv "$__cargo__tar_argv_without_job_homes__argv" "--exclude=./$__cargo__tar_argv_without_job_homes__home"
    done
    @push __cargo__tar_argv_without_job_homes__out "$__cargo__tar_argv_without_job_homes__argv" '.' -cf - .
    println "$__cargo__tar_argv_without_job_homes__out"
  }
}

: <<'FUN'
Copies the tree at <root> into <dest> for a sandboxed publish, through the
invocation __cargo__tar_argv_without_job_homes builds.

args:
  $1  The workspace root
  $2  The destination directory
FUN
__cargo__copy_tree_without_job_homes() {
  __cargo__copy_tree_without_job_homes__argv="$(__cargo__tar_argv_without_job_homes "$1")"
  @apply tar "$__cargo__copy_tree_without_job_homes__argv" | tar -C "$2" -xf -
}

: <<'FUN'
Prints the name of the variable that carries the internal registry's token:
CARGO_REGISTRIES_<REGISTRY>_TOKEN, with the registry name upper-cased.

  __cargo__internal_registry_token_var  ->  CARGO_REGISTRIES_INTERNAL_TOKEN
FUN
__cargo__internal_registry_token_var() {
  __cargo__INTERNAL_TOKEN_VAR_UPPER="$(printf '%s' "$__cargo__workspace_publish__CARGO_PUBLISH_INTERNAL_REGISTRY" | tr '[:lower:]' '[:upper:]')"
  printf 'CARGO_REGISTRIES_%s_TOKEN\n' "$__cargo__INTERNAL_TOKEN_VAR_UPPER"
}

: <<'FUN'
Prints the internal registry's token, or nothing when its variable is unset.
FUN
__cargo__internal_registry_token() {
  __cargo__INTERNAL_TOKEN_VAR="$(__cargo__internal_registry_token_var)"
  eval "printf '%s\n' \"\${${__cargo__INTERNAL_TOKEN_VAR}:-}\""
}

: <<'FUN'
Publishes every pending workspace member to the internal registry from a
sandbox copy of the workspace whose path dependencies name that registry,
with --no-verify since verification would resolve them from crates.io.

args:
  $1  The version being published
FUN
__cargo__publish_to_internal() {
  __cargo__PUBLISH_INTERNAL_VERSION="$1"
  __cargo__PUBLISH_INTERNAL_WORKSPACE_ROOT="$(cargo__workspace_root "$__cargo__CARGO_PUBLISH_MANIFEST")"

  __cargo__PUBLISH_INTERNAL_TMPDIR="$(mktemp -d)"
  trap 'rm -rf "$__cargo__PUBLISH_INTERNAL_TMPDIR"' EXIT

  log "Creating sandbox copy for internal publish..."
  __cargo__copy_tree_without_job_homes "$__cargo__PUBLISH_INTERNAL_WORKSPACE_ROOT" "$__cargo__PUBLISH_INTERNAL_TMPDIR"

  __cargo__PUBLISH_INTERNAL_TMP_MANIFEST="$__cargo__PUBLISH_INTERNAL_TMPDIR/$CARGO_MANIFEST_FILE"
  cargo__workspace_inject_dep_registry "$__cargo__workspace_publish__CARGO_PUBLISH_INTERNAL_REGISTRY" "$__cargo__PUBLISH_INTERNAL_TMP_MANIFEST"

  log "Publishing to ${__cargo__workspace_publish__CARGO_PUBLISH_INTERNAL_REGISTRY} registry..."
  __cargo__CARGO_PUBLISH_REGISTRY="$__cargo__workspace_publish__CARGO_PUBLISH_INTERNAL_REGISTRY"
  __cargo__CARGO_PUBLISH_NO_VERIFY="--no-verify"
  __cargo__PUBLISH_INTERNAL_SAVED_MANIFEST="$__cargo__CARGO_PUBLISH_MANIFEST"
  __cargo__CARGO_PUBLISH_MANIFEST="$__cargo__PUBLISH_INTERNAL_TMP_MANIFEST"
  __cargo__run_workspace_publish "$__cargo__PUBLISH_INTERNAL_VERSION"

  rm -rf "$__cargo__PUBLISH_INTERNAL_TMPDIR"
  trap - EXIT
  __cargo__CARGO_PUBLISH_MANIFEST="$__cargo__PUBLISH_INTERNAL_SAVED_MANIFEST"
}

: <<'FUN'
Publishes every pending workspace member to crates.io with full verification.

args:
  $1  The version being published
FUN
__cargo__publish_to_crates_io() {
  __cargo__CARGO_PUBLISH_REGISTRY="crates-io"
  __cargo__CARGO_PUBLISH_NO_VERIFY=""
  __cargo__run_workspace_publish "$1"
}

: <<'FUN'
Publishes to the internal registry when its token is present, then to
crates.io when the version's channel reaches the confidence gate and
CARGO_REGISTRY_TOKEN is present. Each registry is decided on its own: one
whose token is missing is skipped with a warning, so a repo with no internal
registry still reaches crates.io. Fails only when neither token is set, since
then nothing it was asked for can happen.

args:
  $1  The version being published
FUN
__cargo__dual_publish() {
  __cargo__DUAL_PUB_VERSION="$1"
  __cargo__DUAL_PUB_INTERNAL_TOKEN_VAR="$(__cargo__internal_registry_token_var)"
  __cargo__DUAL_PUB_INTERNAL_TOKEN="$(__cargo__internal_registry_token)"

  if ! @defined "$__cargo__DUAL_PUB_INTERNAL_TOKEN" && [ -z "${CARGO_REGISTRY_TOKEN:-}" ]; then
    error "Neither ${__cargo__DUAL_PUB_INTERNAL_TOKEN_VAR} nor CARGO_REGISTRY_TOKEN is set — cannot publish anywhere"
    return 1
  fi

  if @defined "$__cargo__DUAL_PUB_INTERNAL_TOKEN"; then
    __cargo__publish_to_internal "$__cargo__DUAL_PUB_VERSION"
  else
    warn "${__cargo__DUAL_PUB_INTERNAL_TOKEN_VAR} is not set — skipping the ${__cargo__workspace_publish__CARGO_PUBLISH_INTERNAL_REGISTRY} registry"
  fi

  if ! versions__version_meets_confidence "$__cargo__DUAL_PUB_VERSION" "$__cargo__workspace_publish__CARGO_PUBLISH_CONFIDENCE_GATE"; then
    log "Version $__cargo__DUAL_PUB_VERSION is below ${__cargo__workspace_publish__CARGO_PUBLISH_CONFIDENCE_GATE} confidence — not publishing to crates.io"
    return 0
  fi

  if [ -z "${CARGO_REGISTRY_TOKEN:-}" ]; then
    warn "CARGO_REGISTRY_TOKEN is not set — skipping crates.io for $__cargo__DUAL_PUB_VERSION"
    return 0
  fi

  log "Version $__cargo__DUAL_PUB_VERSION meets ${__cargo__workspace_publish__CARGO_PUBLISH_CONFIDENCE_GATE} confidence — also publishing to crates.io"
  __cargo__publish_to_crates_io "$__cargo__DUAL_PUB_VERSION"
}

__cargo__collect_publish_excludes() {
  __cargo__COLLECT_EXCL_VERSION="$1"
  __cargo__COLLECT_EXCL_MEMBERS="$(cargo__workspace_get_publishable_members "$__cargo__CARGO_PUBLISH_MANIFEST")"

  __cargo__CARGO_PUBLISH_EXCLUDE_ARGS=""
  __cargo__CARGO_PUBLISH_PENDING=0

  @foreach __cargo__classify_member "$__cargo__COLLECT_EXCL_MEMBERS" "$__cargo__COLLECT_EXCL_VERSION"
}

__cargo__classify_member() {
  __cargo__CLASSIFY_ELEMENT="$1"
  __cargo__CLASSIFY_VERSION="$2"
  @unwrap __cargo__CLASSIFY_PKG "$__cargo__CLASSIFY_ELEMENT"

  if @is_true "$(__cargo__is_already_published "$__cargo__CLASSIFY_PKG" "$__cargo__CLASSIFY_VERSION" "$__cargo__CARGO_PUBLISH_REGISTRY")"; then
    log "  $__cargo__CLASSIFY_PKG@$__cargo__CLASSIFY_VERSION already published, excluding"
    __cargo__CARGO_PUBLISH_EXCLUDE_ARGS="${__cargo__CARGO_PUBLISH_EXCLUDE_ARGS} --exclude ${__cargo__CLASSIFY_PKG}"
  else
    __cargo__CARGO_PUBLISH_PENDING=$(( __cargo__CARGO_PUBLISH_PENDING + 1 ))
  fi
}

__cargo__run_workspace_publish() {
  __cargo__RUN_PUB_VERSION="$1"
  __cargo__RUN_PUB_REGISTRY_FLAG=""

  __cargo__collect_publish_excludes "$__cargo__RUN_PUB_VERSION"

  if [ "$__cargo__CARGO_PUBLISH_PENDING" -eq 0 ]; then
    log "All workspace members already published at $__cargo__RUN_PUB_VERSION"
    return 0
  fi

  __cargo__RUN_PUB_REGISTRY_LABEL="${__cargo__CARGO_PUBLISH_REGISTRY:-crates.io}"
  log "Publishing $__cargo__CARGO_PUBLISH_PENDING workspace member(s) to ${__cargo__RUN_PUB_REGISTRY_LABEL}..."
  if [ -n "$__cargo__CARGO_PUBLISH_REGISTRY" ]; then
    __cargo__RUN_PUB_REGISTRY_FLAG="--registry $__cargo__CARGO_PUBLISH_REGISTRY"
  fi

  # shellcheck disable=SC2086
  cargo publish --workspace --allow-dirty $__cargo__RUN_PUB_REGISTRY_FLAG ${__cargo__CARGO_PUBLISH_NO_VERIFY:-} $__cargo__workspace_publish__CARGO_PUBLISH_DRY_RUN \
    $__cargo__CARGO_PUBLISH_EXCLUDE_ARGS \
    ${__cargo__CARGO_PUBLISH_MANIFEST:+--manifest-path "$__cargo__CARGO_PUBLISH_MANIFEST"}
}

: <<'FUN'
Idempotency probe: prints the struct boolean for whether `name@version` already
shows up in the registry's search index. Used to build `--exclude` flags for
workspace publish retries after a partial failure. NOT suitable as a
post-publish availability check against crates.io -- its search index lags the
sparse index that `cargo publish` waits on. For idempotency on retries, `cargo
search`'s eventual consistency is fine: by the time a human re-runs the publish
workflow, the search index has caught up.
FUN
__cargo__is_already_published() {
  __cargo__IS_PUB_NAME="$1"
  __cargo__IS_PUB_VERSION="$2"
  __cargo__IS_PUB_REGISTRY="${3:-}"

  if [ -n "$__cargo__IS_PUB_REGISTRY" ]; then
    __cargo__IS_PUB_SEARCH_OUTPUT="$(cargo search "$__cargo__IS_PUB_NAME" --registry "$__cargo__IS_PUB_REGISTRY" 2>/dev/null || true)"
  else
    __cargo__IS_PUB_SEARCH_OUTPUT="$(cargo search "$__cargo__IS_PUB_NAME" 2>/dev/null || true)"
  fi

  println "$__cargo__IS_PUB_SEARCH_OUTPUT" \
    | { @succeeds __cargo__is_already_published__out grep -q "^${__cargo__IS_PUB_NAME}[[:space:]]*=[[:space:]]*\"${__cargo__IS_PUB_VERSION}\""; println "$__cargo__is_already_published__out"; }
}
