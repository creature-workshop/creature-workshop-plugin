#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/manifest/api.sh" \
  "$SHELLOPS_DIR/lib/self/config.sh" \
  "$SHELLOPS_DIR/lib/self/lock/api.sh" \
  "$SHELLOPS_DIR/lib/versions/api.sh"

: <<'MODULE'
The release record of a repository: the versions it has released, kept
in its lock file, .ops/lock, under the key release (ADR 000049). The
record has two fields. latest is the newest version the release process
has recorded, a prerelease or a release. stable is the newest release, so
it never names a prerelease. Each field has a getter and a setter here,
and releases__record__set_version moves both at once, the way a release
does. The release process writes the record; everything else only reads
it. A repository that kept its record in a manifest before it had a lock
gets it copied into the lock once, by releases__record__copy_from_manifest.
A released version is also recorded as a commit, the record commit, in
lib/releases/record/commit.sh.
MODULE

# CONST: The section of the lock the record sits under.
__releases__record__SECTION='release'

: <<'PUB_FUN'
Prints latest, the newest version the release process recorded for the
repository at <root>, $PROJ when omitted. Reads the lock first. When the
lock has no latest, reads manifest.json, where a repository kept its
record before it had a lock. Fails, with a message, when neither has it.

  releases__record__get_latest   ->  0.66.0-dev.122

args:
  $1  The repository's root; $PROJ when omitted
PUB_FUN
releases__record__get_latest() {
  __releases__record__get_field latest "${1:-}"
}

: <<'PUB_FUN'
Prints stable, the newest release recorded for the repository at <root>,
$PROJ when omitted, read the way releases__record__get_latest reads
latest.

  releases__record__get_stable   ->  0.65.0

args:
  $1  The repository's root; $PROJ when omitted
PUB_FUN
releases__record__get_stable() {
  __releases__record__get_field stable "${1:-}"
}

: <<'PUB_FUN'
Sets latest to <version> in the lock of <root>, $PROJ when omitted, and
writes the lock. Everything else in the lock is kept.

args:
  $1  The version
  $2  The repository's root; $PROJ when omitted
PUB_FUN
releases__record__set_latest() {
  __releases__record__set_field latest "$1" "${2:-}"
}

: <<'PUB_FUN'
Sets stable to <version> in the lock of <root>, $PROJ when omitted, and
writes the lock. Everything else in the lock is kept.

args:
  $1  The version
  $2  The repository's root; $PROJ when omitted
PUB_FUN
releases__record__set_stable() {
  __releases__record__set_field stable "$1" "${2:-}"
}

: <<'PUB_FUN'
Records the version <version> the way a release does: sets latest to it,
and stable too when it is a release version. Only a release moves stable,
so stable is always the last release cut, and a prerelease never reaches
it. In the lock of <root>, $PROJ when omitted.

  releases__record__set_version 1.2.0-rc.1          latest alone
  releases__record__set_version 1.2.0 /tmp/record   latest and stable

args:
  $1  The version
  $2  The repository's root; $PROJ when omitted
PUB_FUN
releases__record__set_version() {
  releases__record__set_latest "$1" "${2:-}" || return 1
  if versions__is_release_version "$1"; then
    releases__record__set_stable "$1" "${2:-}" || return 1
  fi
}

: <<'PUB_FUN'
Copies the release record into the lock of <root>, $PROJ when omitted,
from the manifest declaration a repository kept it in before it had a
lock: latest, stable, and the count of releases. Copies once: a lock that
already records latest is left as it is, and a repository whose manifest
declares no record gets none. Prints true when it copied a record and
false when it did not.

args:
  $1  The repository's root; $PROJ when omitted
PUB_FUN
releases__record__copy_from_manifest() {
  __releases__record__copy_from_manifest__root="${1:-$PROJ}"
  if @is_true "$(__releases__record__recorded "$__releases__record__copy_from_manifest__root")"; then
    @false __releases__record__copy_from_manifest__out
    println "$__releases__record__copy_from_manifest__out"
    return 0
  fi
  if @is_false "$(self__config__present manifest "$__releases__record__copy_from_manifest__root")"; then
    @false __releases__record__copy_from_manifest__out
    println "$__releases__record__copy_from_manifest__out"
    return 0
  fi
  __releases__record__copy_fields "$__releases__record__copy_from_manifest__root" || return 1
  __releases__record__recorded "$__releases__record__copy_from_manifest__root"
}

: <<'FUN'
Prints true when the lock of <root> records latest, false otherwise.

args:
  $1  The repository's root
FUN
__releases__record__recorded() {
  @succeeds __releases__record__recorded__out @defined "$(__releases__record__from_lock latest "$1")"
  println "$__releases__record__recorded__out"
}

: <<'FUN'
Copies latest, stable and releases from the manifest declaration of
<root> into its lock, each when the declaration has it. Fails when the
declaration does not load.

args:
  $1  The repository's root
FUN
__releases__record__copy_fields() {
  __releases__record__copy_fields__manifest="$(self__config__load manifest "$1")" || return 1
  __releases__record__copy_field latest "$__releases__record__copy_fields__manifest" "$1" || return 1
  __releases__record__copy_field stable "$__releases__record__copy_fields__manifest" "$1" || return 1
  __releases__record__copy_field releases "$__releases__record__copy_fields__manifest" "$1"
}

: <<'FUN'
Copies the field <field> of the manifest declaration <manifest> into the
lock of <root>, when the declaration has it. Prints nothing.

args:
  $1  The field
  $2  The manifest declaration, as a struct
  $3  The repository's root
FUN
__releases__record__copy_field() {
  @get __releases__record__copy_field__value "$2" ".$1" ''
  if @defined "$__releases__record__copy_field__value"; then
    __releases__record__set_field "$1" "$__releases__record__copy_field__value" "$3"
  fi
}

: <<'FUN'
Prints the field <field> of the release record of the repository at
<root>, $PROJ when omitted. Reads the lock first. When the lock has no
such field, reads manifest.json, where a repository kept its record
before it had a lock. Fails, with a message, when neither has the field.

args:
  $1  The field
  $2  The repository's root; $PROJ when omitted
FUN
__releases__record__get_field() {
  __releases__record__get_field__value="$(__releases__record__from_lock "$1" "${2:-}")" || return 1
  if @defined "$__releases__record__get_field__value"; then
    println "$__releases__record__get_field__value"
    return 0
  fi
  manifest__get "$1"
}

: <<'FUN'
Prints the field <field> of the release record in the lock of <root>,
$PROJ when omitted, and nothing when the repository has no lock or the
lock has no such field.

args:
  $1  The field
  $2  The repository's root; $PROJ when omitted
FUN
__releases__record__from_lock() {
  @get __releases__record__from_lock__out "$(self__lock__get_section "$__releases__record__SECTION" "${2:-}")" ".$1" ''
  println "$__releases__record__from_lock__out"
}

: <<'FUN'
Sets the field <field> of the release record to <value> in the lock of
<root>, $PROJ when omitted, and writes the lock. Everything else in the
lock is kept.

args:
  $1  The field
  $2  The value
  $3  The repository's root; $PROJ when omitted
FUN
__releases__record__set_field() {
  __releases__record__set_field__record="$(self__lock__get_section "$__releases__record__SECTION" "${3:-}")"
  @set __releases__record__set_field__record "$__releases__record__set_field__record" ".$1" "$2"
  self__lock__set_section "$__releases__record__SECTION" "$__releases__record__set_field__record" "${3:-}"
}
