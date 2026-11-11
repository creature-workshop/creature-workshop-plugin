#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/self/lock/reconcile.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
The lock is the file .ops/lock. It records what the resolvers derived from
the declarations under .ops/config, and it is the one derived file that a
repository tracks in git (ADR 000049; ADR.21@global lists what every
repository carries). Nobody edits it by hand.

The lock is a map of sections. Each section is named after the declaration
it is derived from, and the module that derives it writes it. The sections
today are:

- seeds: the doc seed and the line seed that the owner's Strata ids are
  drawn from (ADR 000035).
- release: the record the release job writes. latest is the version the
  repository last recorded, and stable is the last clean release
  (ADR 000044).
- dependencies: the resolved graph. dependencies.imports lists the
  run-time trees, and dependencies.tools lists the tools by channel, the
  git channel's trees among them.
- features: the health report of the repository's own features.
- intake: what ops intake derived from intake.yaml.

This module owns the high level shape of the file and provides a way to
read and write it. It purposely leaves individual sections of the lockfile
to be managed elsewhere as their own modules. The one exception is seeds:
self__lock__seed and self__lock__set_seeds live here, because the boot
reads a seed before the structs library has loaded. The reconcile
fragment, reconcile.sh, compares a declared list with what a remote holds
and prints the section that records the result.

The shape of the file is fixed, for two reasons:

- The boot reads the file without a JSON reader. So the file is pretty
  JSON with one member per line, and self__lock__seed finds a seed by
  walking that nesting in awk.
- Git tracks the file. So the sections are always in the same order: seeds
  first, when the lock has them, then every other section in alphabetical
  order (ADR 000056). Two writes of the same content produce the same
  bytes, and a rewrite that changes nothing shows no diff.

  {
    "seeds": { "doc": 335499942, "line": 2931084477 },
    "dependencies": { "tools": { "system": { "jq": { "version": "1.6" } } } },
    "features": {},
    "release": { "latest": "0.66.0-dev.122", "stable": "0.65.0" }
  }
MODULE

# CONST: The lock's path under a repository.
__self__lock__FILE='.ops/lock'

# CONST: The key the seeds sit under.
__self__lock__SEEDS='seeds'

# CONST: The awk program that reads the lock's lines by nesting. Every awk program over the lock loads it first.
__self__lock__LINES_AWK="$SHELLOPS_DIR/lib/self/lock/lines.awk"

# CONST: The awk that prints the scalar at a dotted path of the lock.
__self__lock__PATH_AWK="$SHELLOPS_DIR/lib/self/lock/path.awk"

: <<'PUB_FUN'
Prints the path of the lock of the repository <root>, whether or not the
file exists.

  self__lock__path /repo   ->  /repo/.ops/lock

args:
  $1  The repository's root; $PROJ when omitted
PUB_FUN
self__lock__path() {
  printf '%s/%s\n' "${1:-$PROJ}" "$__self__lock__FILE"
}

: <<'PUB_FUN'
Prints true when the repository <root> has a lock, false otherwise.

args:
  $1  The repository's root; $PROJ when omitted
PUB_FUN
self__lock__present() {
  if [ -f "$(self__lock__path "${1:-}")" ]; then
    @true __self__lock__present__out
    println "$__self__lock__present__out"
  else
    @false __self__lock__present__out
    println "$__self__lock__present__out"
  fi
}

: <<'PUB_FUN'
Prints the lock of the repository <root> as a struct, or the empty lock
when the repository has none yet. A writer reads this, changes one
section, and writes the whole back.

args:
  $1  The repository's root; $PROJ when omitted
PUB_FUN
self__lock__read() {
  __self__lock__read__file="$(self__lock__path "${1:-}")"
  if [ -f "$__self__lock__read__file" ]; then
    cat "$__self__lock__read__file"
  else
    self__lock__empty
  fi
}

: <<'PUB_FUN'
Prints the empty lock, the empty map: a lock has no section until the
module that derives one writes it.

  self__lock__empty   ->  {}
PUB_FUN
self__lock__empty() {
  @obj __self__lock__empty__out
  println "$__self__lock__empty__out"
}

: <<'PUB_FUN'
Writes <lock> as the lock of <root>, in the fixed shape: pretty-printed,
seeds first when the lock has them, then every other section in
alphabetical order. The file is written fresh beside the lock and then
moved into place, so a reader never sees a half-written lock. When the
lock on disk already has exactly this content, it is left untouched, so
its timestamp does not change.

args:
  $1  The lock, as a struct
  $2  The repository's root; $PROJ when omitted
PUB_FUN
self__lock__write() {
  __self__lock__write__file="$(self__lock__path "${2:-}")"
  __self__lock__write__fresh="$__self__lock__write__file.$$"
  mkdir -p "$(dirname "$__self__lock__write__file")"
  @dump __self__lock__write__out "$(__self__lock__canonical "$1")"
  println "$__self__lock__write__out" > "$__self__lock__write__fresh"
  if [ -f "$__self__lock__write__file" ] && cmp -s "$__self__lock__write__fresh" "$__self__lock__write__file"; then
    rm -f "$__self__lock__write__fresh"
    return 0
  fi
  mv "$__self__lock__write__fresh" "$__self__lock__write__file"
}

: <<'PUB_FUN'
Prints one seed from the lock of <root>: the doc seed or the line seed,
under seeds. Prints nothing when the repository has no lock or the lock
has no such seed. This reads the file in awk, by walking its nesting, and
uses no JSON reader, so a caller that runs before the structs library has
loaded can use it.

  self__lock__seed doc /repo   ->  335499942

args:
  $1  Which seed: doc or line
  $2  The repository's root; $PROJ when omitted
PUB_FUN
self__lock__seed() {
  __self__lock__seed__file="$(self__lock__path "${2:-}")"
  [ -f "$__self__lock__seed__file" ] || return 0
  awk \
    -v WANT="$__self__lock__SEEDS.$1" \
    -f "$__self__lock__LINES_AWK" \
    -f "$__self__lock__PATH_AWK" \
    "$__self__lock__seed__file"
}

: <<'PUB_FUN'
Replaces the seeds section of the lock of <root> with the doc seed and
the line seed given, and writes the lock. Everything else in the lock is
kept.

args:
  $1  The doc seed
  $2  The line seed
  $3  The repository's root; $PROJ when omitted
PUB_FUN
self__lock__set_seeds() {
  @obj __self__lock__set_seeds__obj_1 '.doc' "$1" '.line' "$2"
  self__lock__set_section "$__self__lock__SEEDS" "$__self__lock__set_seeds__obj_1" "${3:-}"
}

: <<'PUB_FUN'
Prints the section <name> of the lock of <root> as a struct, or the empty
map when the lock has no such section. A section is named after the
declaration under .ops/config it is derived from, and holds what the
module that derives it recorded. ops intake, for example, records under
intake, for each declared address, the id of the email intake in Linear
and the address Linear generated for it.

  self__lock__get_section intake /repo
    ->  {"docs@example.com":{"id":"3a1c...","address":"2371...@intake.linear.app"}}

args:
  $1  The section's name, which is the declaration's
  $2  The repository's root; $PROJ when omitted
PUB_FUN
self__lock__get_section() {
  @obj __self__lock__get_section__obj_2
  @get __self__lock__get_section__out "$(self__lock__read "${2:-}")" ".$1" "$__self__lock__get_section__obj_2"
  println "$__self__lock__get_section__out"
}

: <<'PUB_FUN'
Replaces the section <name> of the lock of <root> with <value> and writes
the lock. Everything else in the lock is kept.

args:
  $1  The section's name, which is the declaration's
  $2  The section, as a struct
  $3  The repository's root; $PROJ when omitted
PUB_FUN
self__lock__set_section() {
  __self__lock__set_section__lock="$(self__lock__read "${3:-}")"
  @set __self__lock__set_section__lock "$__self__lock__set_section__lock" ".$1" "$2"
  self__lock__write "$__self__lock__set_section__lock" "${3:-}"
}

: <<'FUN'
Prints <lock> with its sections in the fixed order: seeds first when the
lock has them, then every other section in alphabetical order. Every write
goes through this, so two writes of the same content produce the same
file.

args:
  $1  The lock, as a struct
FUN
__self__lock__canonical() {
  __self__lock__canonical__source="$1"
  __self__lock__canonical__lock="$(__self__lock__seeds_first "$__self__lock__canonical__source")"
  @keys __self__lock__canonical__keys_3 "$__self__lock__canonical__source"
  @reduce __self__lock__canonical__out __self__lock__copy_section \
    "$__self__lock__canonical__keys_3" \
    "$__self__lock__canonical__lock" \
    "$__self__lock__canonical__source"
  println "$__self__lock__canonical__out"
}

: <<'FUN'
Prints a map with the seeds of <lock> alone, or the empty map when <lock>
has no seeds. The canonical lock starts from this map, so the seeds come
first. The order is fixed so that a write is deterministic. The seeds lead
because they are the project's identity and small, so they read as a
header for the file. No reader depends on where a section sits
(ADR 000056).

args:
  $1  The lock, as a struct
FUN
__self__lock__seeds_first() {
  @get __self__lock__seeds_first__seeds "$1" ".$__self__lock__SEEDS" ''
  if @defined "$__self__lock__seeds_first__seeds"; then
    @obj __self__lock__seeds_first__out ".$__self__lock__SEEDS" "$__self__lock__seeds_first__seeds"
    println "$__self__lock__seeds_first__out"
  else
    @obj __self__lock__seeds_first__out
    println "$__self__lock__seeds_first__out"
  fi
}

: <<'FUN'
@reduce callback: copies the section named <key> from <source> onto
<lock> and prints the result. The seeds are skipped, because the canonical
lock already starts with them.

args:
  $1  The lock being built, as a struct
  $2  The key, wrapped
  $3  The lock the section is read from, as a struct
FUN
__self__lock__copy_section() {
  @unwrap __self__lock__copy_section__key "$2"
  if [ "$__self__lock__copy_section__key" = "$__self__lock__SEEDS" ]; then
    println "$1"
  else
    @get __self__lock__copy_section__get_4 "$3" ".$__self__lock__copy_section__key"
    @set __self__lock__copy_section__out "$1" ".$__self__lock__copy_section__key" "$__self__lock__copy_section__get_4"
    println "$__self__lock__copy_section__out"
  fi
}
