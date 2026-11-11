#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/self/structs.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
A repository's declarations under .ops/config/: manifest, ecosystems, tools,
imports, features, secrets, lint, profiling and intake, each a YAML file that a person or an
agent writes and the resolver derives the lock from (ADR 000049, and
ADR.21@global for what every repository carries). This module locates a
declaration and reads it as a struct.

A declaration is read through SILT's YAML translator, in the strata tree
that boot fetches before anything else (ADR 000048). So the read needs no
tool that the declarations install: @from_yaml runs on yq, which tools.yaml
provisions, and could not read tools.yaml itself.

While repositories convert (OPS-1462), a name whose file is absent falls
back to the root file it replaces: manifest and ecosystems to
manifest.json, tools to ops.lock, and lint to lint.json. A reader with a
default for a missing declaration asks self__config__present before it loads.

  self__config__path tools        ->  /p/.ops/config/tools.yaml
  self__config__present tools     ->  true
  self__config__load tools        ->  {"system":{"jq":{"version":"1.6"}},...}
  self__config__get tools '.system.jq.version' 1.7.1   ->  1.6
MODULE

# CONST: The directory under a repository that holds its declarations.
__self__config__DIR='.ops/config'

# CONST: The root file each declaration replaces, read while a repository has not converted.
@obj __self__config__FALLBACKS \
  '.manifest' 'manifest.json' \
  '.ecosystems' 'manifest.json' \
  '.tools' 'ops.lock' \
  '.lint' 'lint.json'

: <<'PUB_FUN'
Prints the path of the declaration <name> under the repository <root>,
whether or not the file exists.

  self__config__path tools /p   ->  /p/.ops/config/tools.yaml

args:
  $1  The declaration's name: manifest, ecosystems, tools, imports,
      features, secrets, lint, profiling or intake
  $2  The repository's root; $PROJ when omitted
PUB_FUN
self__config__path() {
  printf '%s/%s/%s.yaml\n' "${2:-$PROJ}" "$__self__config__DIR" "$1"
}

: <<'PUB_FUN'
Prints true when the repository <root> has the declaration <name>, either
as its file under .ops/config/ or as the root file it replaces, and false
otherwise. A reader with a default for a missing declaration asks this
before it loads, because a missing file and an unreadable one fail the
load alike.

  self__config__present lint   ->  false

args:
  $1  The declaration's name
  $2  The repository's root; $PROJ when omitted
PUB_FUN
self__config__present() {
  __self__config__present__file="$(self__config__path "$1" "${2:-}")"
  __self__config__present__fallback="$(__self__config__fallback "$1" "${2:-}")"

  if [ -f "$__self__config__present__file" ]; then
    @true __self__config__present__out
    println "$__self__config__present__out"
  elif @defined "$__self__config__present__fallback" && [ -f "$__self__config__present__fallback" ]; then
    @true __self__config__present__out
    println "$__self__config__present__out"
  else
    @false __self__config__present__out
    println "$__self__config__present__out"
  fi
}

: <<'PUB_FUN'
Prints the declaration <name> of the repository <root> as a struct. Reads
the file under .ops/config/ when it exists, else the root file it replaces.
Fails, naming both files, when neither exists, and fails when the file does
not parse.

  self__config__load tools   ->  {"system":{"jq":{"version":"1.6"}},...}

args:
  $1  The declaration's name
  $2  The repository's root; $PROJ when omitted
PUB_FUN
self__config__load() {
  __self__config__load__file="$(self__config__path "$1" "${2:-}")"
  __self__config__load__fallback="$(__self__config__fallback "$1" "${2:-}")"

  if [ -f "$__self__config__load__file" ]; then
    __self__config__read_yaml "$__self__config__load__file"
  elif @defined "$__self__config__load__fallback" && [ -f "$__self__config__load__fallback" ]; then
    __self__config__read_legacy "$1" "$__self__config__load__fallback"
  else
    __self__config__missing "$1" "$__self__config__load__file" "$__self__config__load__fallback"
    return 1
  fi
}

: <<'PUB_FUN'
Prints the value at <path> of the declaration <name> of the repository
<root>, or <default> when the repository has no such declaration or the
declaration has nothing at that path. A reader with a default for a
setting a repository may leave out asks this in place of loading. Fails,
saying why, when the declaration exists and cannot be read.

  self__config__get tools '.system.jq.version' 1.7.1       ->  1.6
  self__config__get docs '.site.branch' published          ->  published
  self__config__get docs '.site.branch' published /site    ->  main

args:
  $1  The declaration's name
  $2  The path, as @get reads one
  $3  The default
  $4  The repository's root; $PROJ when omitted
PUB_FUN
self__config__get() {
  if ! @is_true "$(self__config__present "$1" "${4:-}")"; then
    println "$3"
    return 0
  fi
  __self__config__get__declaration="$(self__config__load "$1" "${4:-}")" || return 1
  @get __self__config__get__out "$__self__config__get__declaration" "$2" "$3"
  println "$__self__config__get__out"
}

: <<'FUN'
Reports that the declaration <name> is absent: its file <file> does not
exist, and neither does the root file <fallback> it replaces, when it has
one.

args:
  $1  The declaration's name
  $2  The declaration's file
  $3  The root file it replaces, or the empty string
FUN
__self__config__missing() {
  if @defined "$3"; then
    error "no $1 declaration: $2 is absent, and so is $3"
  else
    error "no $1 declaration: $2 is absent"
  fi
}

: <<'FUN'
Prints the path of the root file the declaration <name> replaces under the
repository <root>, or nothing when the declaration has no such file.

  __self__config__fallback tools /p   ->  /p/ops.lock

args:
  $1  The declaration's name
  $2  The repository's root; $PROJ when omitted
FUN
__self__config__fallback() {
  @get __self__config__fallback__file "$__self__config__FALLBACKS" ".$1" ''
  if @defined "$__self__config__fallback__file"; then
    printf '%s/%s\n' "${2:-$PROJ}" "$__self__config__fallback__file"
  fi
}

: <<'FUN'
Prints the YAML file <file> as a struct, read through SILT's translator in
the strata tree SILT_DIR names. Fails when SILT_DIR is unset or the file
does not parse as YAML.

args:
  $1  The YAML file
FUN
__self__config__read_yaml() {
  self__structs__silt || return 1

  if ! silt__from_yaml __self__config__read_yaml__doc < "$1"; then
    error "$1 does not read as YAML"
    return 1
  fi
  silt__to_json __self__config__read_yaml__json "$__self__config__read_yaml__doc" || return 1
  println "$__self__config__read_yaml__json"
}

: <<'FUN'
Prints the legacy root file <file> as the struct the declaration <name>
would hold: the file as it is, except that the ecosystems declaration is
the "ecosystems" member of manifest.json. The file is printed and not
reshaped, because ops install reads the tools declaration before it has
installed jq.

args:
  $1  The declaration's name
  $2  The root file
FUN
__self__config__read_legacy() {
  if [ "$1" = ecosystems ]; then
    @obj __self__config__read_legacy__obj_1
    @get __self__config__read_legacy__out "$(cat "$2")" '.ecosystems' "$__self__config__read_legacy__obj_1"
    println "$__self__config__read_legacy__out"
  else
    cat "$2"
  fi
}
