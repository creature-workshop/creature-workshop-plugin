#!/bin/sh

: <<'MODULE'
Reading the project's manifest: the declaration a person writes, read
through the config module and checked against manifest.schema.json. The
release record, latest and stable, lives in the lock (ADR 000049); a
manifest.json that still carries it, in a repository that has not
converted, is read here for compatibility, by lib/releases/record/api.sh.

A key that the manifest leaves out and a key that is null read the same.
Both are unset, and manifest__get prints the key's default. A key with no
default of its own has the empty default, so manifest__get prints nothing
for it. false, 0 and the empty string are values, and manifest__get prints
them. The schema says which keys can be null.

The key table gives each logical key either its path in the manifest (it
starts with . or [) or the name of a function. manifest__get calls the
function to compute the value on first access.
MODULE

import \
  "$SHELLOPS_DIR/lib/self/config.sh" \
  "$SHELLOPS_DIR/lib/labels/api.sh"

__manifest__api_schema_file="$SHELLOPS_DIR/schema/manifest.schema.json"

@obj __manifest__api_cache

: <<'CONST'
Memoization keyed by logical schema key. A single struct object stands in for
the bash associative array we can't use in POSIX sh. manifest__get takes a
cached value only when it is defined, so it reads a key that prints nothing
from the manifest again on every call.
CONST
__manifest__API_CACHE="$__manifest__api_cache"

: <<'FUN'
Resolves a logical manifest key to its entry in the key table: either the
key's path in the manifest or the name of a function that computes the
value. Returns non-zero for unknown keys.

Usage: __manifest__api_schema_path <key>
FUN
__manifest__api_schema_path() {
  case "$1" in
    command_name)    echo '."command-name"' ;;
    description)     echo '.description' ;;
    org)             echo '.org' ;;
    repo)            echo '.repo' ;;
    latest)          echo '.latest' ;;
    stable)          echo '.stable' ;;
    bump__default_channel) echo '."default-channel"' ;;
    bump__auto_promote_until) echo '."auto-promote-until"' ;;
    promotion)       echo '.promotion' ;;
    version_format)  echo '."version-format"' ;;
    major_name)      echo '.naming.major' ;;
    minor_name)      echo '.naming.minor' ;;
    patch_name)      echo '.naming.patch' ;;
    godot_version)   echo '.engines.godot.version' ;;
    godot_url)       echo '.engines.godot.url' ;;
    godot_supported) echo '__manifest__godot_supported' ;;
    linear_team)     echo '."linear-team"' ;;
    ecosystems)      echo '.ecosystems' ;;
    cargo_declared)  echo '__manifest__cargo_declared' ;;
    cargo_path)      echo '.ecosystems.cargo.path' ;;
    cargo_workspace) echo '.ecosystems.cargo.workspace' ;;
    agents_providers) echo '.agents.providers' ;;
    labels)          echo 'labels__merged_labels' ;;
    *)               return 1 ;;
  esac
}

: <<'FUN'
Prints the default of the key <key>, which is what manifest__get prints
when the key is unset. A key with no default of its own has the empty
default and prints an empty line. Returns non-zero for latest and stable:
the release record has no default, and a repository with no record fails
the read.

  __manifest__api_default version_format  ->  increment

Usage: __manifest__api_default <key>
FUN
__manifest__api_default() {
  case "$1" in
    bump__default_channel)    println dev ;;
    bump__auto_promote_until) println stable ;;
    version_format)           println increment ;;
    cargo_path)               println Cargo.toml ;;
    cargo_workspace)          __manifest__default_true ;;
    ecosystems | agents_providers) __manifest__default_empty_map ;;
    latest | stable)          return 1 ;;
    *)                        println '' ;;
  esac
}

: <<'FUN'
Prints the struct boolean true, the default of a flag that is on unless
the manifest turns it off.
FUN
__manifest__default_true() {
  @true __manifest__default_true__out
  println "$__manifest__default_true__out"
}

: <<'FUN'
Prints an empty struct map, the default of a key that holds a map.
FUN
__manifest__default_empty_map() {
  @obj __manifest__default_empty_map__out
  println "$__manifest__default_empty_map__out"
}

: <<'FUN'
Reads the key <key> from <path> of the manifest into __manifest__GET_VALUE:
the value when the key holds one, and the key's default when the key is
unset, which is when the manifest leaves it out or has it as null. Fails
when the manifest cannot be read, and when an unset key has no default.

args:
  $1  The logical key
  $2  The key's path in the manifest
FUN
__manifest__get__read_path() {
  if ! __manifest__get__read_path__manifest="$(__manifest__load)"; then
    log "Failed to read manifest key '$1'"
    return 1
  fi

  @typeof __manifest__get__read_path__type "$__manifest__get__read_path__manifest" "$2" || return 1
  if [ "$__manifest__get__read_path__type" = null ]; then
    __manifest__get__read_default "$1"
  else
    __manifest__get__read_value "$1" "$__manifest__get__read_path__manifest" "$2"
  fi
}

: <<'FUN'
Sets __manifest__GET_VALUE to the value the manifest <manifest> holds at
<path>, for a key that holds one.

args:
  $1  The logical key
  $2  The manifest
  $3  The key's path in the manifest
FUN
__manifest__get__read_value() {
  __manifest__get__read_value__key="$1"
  __manifest__get__read_value__manifest="$2"
  __manifest__get__read_value__path="$3"

  if ! @get __manifest__GET_VALUE "$__manifest__get__read_value__manifest" "$__manifest__get__read_value__path"; then
    log "Failed to read manifest key '$__manifest__get__read_value__key'"
    return 1
  fi
}

: <<'FUN'
Sets __manifest__GET_VALUE to the default of the key <key>, for a key that
is unset. Fails, naming the key, when the key has no default.

args:
  $1  The logical key
FUN
__manifest__get__read_default() {
  if ! __manifest__GET_VALUE="$(__manifest__api_default "$1")"; then
    log "manifest key '$1' is unset, and it has no default"
    return 1
  fi
}

: <<'FUN'
Prints the Godot versions the manifest lists under engines.godot.supported,
joined by commas, and an empty line when the list is unset.

  __manifest__godot_supported  ->  4.2,4.3
FUN
__manifest__godot_supported() {
  __manifest__godot_supported__manifest="$(__manifest__load)" || return 1
  @arr __manifest__godot_supported__none
  @get __manifest__godot_supported__versions "$__manifest__godot_supported__manifest" '.engines.godot.supported' "$__manifest__godot_supported__none" || return 1
  @join __manifest__godot_supported__out "$__manifest__godot_supported__versions" ',' || return 1
  println "$__manifest__godot_supported__out"
}

: <<'FUN'
Prints true when the manifest declares the cargo ecosystem, and false when
it does not.
FUN
__manifest__cargo_declared() {
  __manifest__cargo_declared__manifest="$(__manifest__load)" || return 1
  @get __manifest__cargo_declared__block "$__manifest__cargo_declared__manifest" '.ecosystems.cargo' || return 1
  @succeeds __manifest__cargo_declared__out @defined "$__manifest__cargo_declared__block"
  println "$__manifest__cargo_declared__out"
}

: <<'FUN'
Computes a function-valued manifest key into __manifest__GET_VALUE. Expects
__manifest__get__key and __manifest__get__path to be set by manifest__get.

Usage: __manifest__get__read_function
FUN
__manifest__get__read_function() {
  if ! __manifest__GET_VALUE="$("$__manifest__get__path")"; then
    log "Failed to compute manifest.json key '$__manifest__get__key'"
    return 1
  fi
}

: <<'FUN'
Prints the project's manifest declaration as a struct, checked against
manifest.schema.json. Fails when the declaration is absent, does not parse,
or breaks the schema.

Usage: __manifest__load
FUN
__manifest__load() {
  __manifest__load__manifest="$(self__config__load manifest)" || return 1
  @validate "$__manifest__load__manifest" "$__manifest__api_schema_file" || return 1
  println "$__manifest__load__manifest"
}

: <<'PUB_FUN'
Prints true when the project carries a manifest declaration to read, false
when it does not. A reader that has a default for a silent manifest asks
this before reading, since a missing file and an unreadable one are
otherwise the same failure.

Usage: if @is_true "$(manifest__present)"; then ... fi
PUB_FUN
manifest__present() {
  self__config__present manifest
}

: <<'PUB_FUN'
Prints the value of the logical key <key> of the project's manifest. Prints
the key's default when the key is unset, which is when the manifest leaves
it out or has it as null. A key with no default of its own prints an empty
line. Fails for an unknown key, for a manifest that cannot be read, and
for latest or stable when the manifest has no release record.

  <default-channel left out>  manifest__get bump__default_channel  ->  dev
  <default-channel: null>     manifest__get bump__default_channel  ->  dev
  <workspace: false>          manifest__get cargo_workspace        ->  false
  <command-name: null>        manifest__get command_name           ->

Usage: manifest__get <key>
PUB_FUN
manifest__get() {
  __manifest__get__key="$1"

  if ! __manifest__get__path="$(__manifest__api_schema_path "$__manifest__get__key")"; then
    log "Unknown manifest.json key: '$__manifest__get__key'"
    return 1
  fi

  @get __manifest__get__cached "$__manifest__API_CACHE" "$__manifest__get__key" ''
  if @defined "$__manifest__get__cached"; then
    echo "$__manifest__get__cached"
    return 0
  fi

  case "$__manifest__get__path" in
    .* | \[*)
      __manifest__get__read_path "$__manifest__get__key" "$__manifest__get__path" || return 1
      ;;
    *)
      __manifest__get__read_function || return 1
      ;;
  esac

  @set __manifest__API_CACHE "$__manifest__API_CACHE" "$__manifest__get__key" "$__manifest__GET_VALUE"

  echo "$__manifest__GET_VALUE"
}
