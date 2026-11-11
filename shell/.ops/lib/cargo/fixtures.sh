#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"
import "$SHELLOPS_DIR/lib/cargo/api.sh"

: <<'FRAGMENT'
The on-disk cargo shapes a test needs standing up before it can assert
anything.

A fixture is domain knowledge -- what a crate looks like on disk, and what has
to be there alongside it for a case to mean something -- so it belongs to the
module that owns the domain rather than to whichever suite needed it first. It
sits beside api.sh instead of inside it so importing the cargo module does not
hand production code a set of fixtures.

Nothing here knows what runs it: paths are given, not read out of a harness
variable, and results come back as structs.
FRAGMENT

: <<'PUB_FUN'
Builds a bare origin and a working clone holding a seeded crate under <dir>, and
prints their paths as .origin and .work.

<crate> is the crate's directory within the clone, and defaults to its root. A
nested crate gets the root's own Cargo.toml and Cargo.lock as well, so a case
about which pair a sync touches has both pairs to distinguish.

The clone is committed and pushed, so it stands on main at the origin's tip with
a clean tree.

Usage: cargo__fixture_crate_repo <dir> [<crate>]
PUB_FUN
cargo__fixture_crate_repo() {
  __cargo__fixture_crate_repo__origin="$1/origin.git"
  __cargo__fixture_crate_repo__work="$1/work"
  __cargo__fixture_crate_repo__crate="${2:-.}"

  git init -q --bare -b main "$__cargo__fixture_crate_repo__origin"
  git init -q -b main "$__cargo__fixture_crate_repo__work"
  git -C "$__cargo__fixture_crate_repo__work" config user.name test
  git -C "$__cargo__fixture_crate_repo__work" config user.email test@example.com

  cargo__fixture_crate_files "$__cargo__fixture_crate_repo__work"
  if [ "$__cargo__fixture_crate_repo__crate" != "." ]; then
    cargo__fixture_crate_files \
      "$__cargo__fixture_crate_repo__work/$__cargo__fixture_crate_repo__crate"
  fi

  git -C "$__cargo__fixture_crate_repo__work" add .
  git -C "$__cargo__fixture_crate_repo__work" commit -q -m seed
  git -C "$__cargo__fixture_crate_repo__work" remote add origin \
    "$__cargo__fixture_crate_repo__origin"
  git -C "$__cargo__fixture_crate_repo__work" push -q -u origin main

  @obj __cargo__fixture_crate_repo__out \
    '.origin' "$__cargo__fixture_crate_repo__origin" \
    '.work' "$__cargo__fixture_crate_repo__work"
  println "$__cargo__fixture_crate_repo__out"
}

: <<'PUB_FUN'
Writes a versioned Cargo.toml and Cargo.lock at <dir>, creating it if it is not
there. <version> defaults to 1.2.3.

The pair is what a crate is for the purposes of a version sync: one file the
writer edits and one the lock refresh rewrites beside it.

Usage: cargo__fixture_crate_files <dir> [<version>]
PUB_FUN
cargo__fixture_crate_files() {
  __cargo__fixture_crate_files__version="${2:-1.2.3}"

  mkdir -p "$1"
  printf 'version = "%s"\n' "$__cargo__fixture_crate_files__version" > "$1/$CARGO_MANIFEST_FILE"
  printf 'version = "%s"\n' "$__cargo__fixture_crate_files__version" > "$1/Cargo.lock"
}

: <<'PUB_FUN'
Writes a crate at <dir> whose Cargo.toml declares [package] name <name> (which
need not equal the directory name), plus a source file under <dir>/src -- the
shape crate discovery and package lookups resolve against.

Usage: cargo__fixture_package <dir> <name>
PUB_FUN
cargo__fixture_package() {
  mkdir -p "$1/src"
  printf '%s\n' \
    '[package]' \
    "name = \"$2\"" \
    'version = "0.0.0"' \
    'edition = "2021"' \
    > "$1/Cargo.toml"
  touch "$1/src/lib.rs"
}

: <<'PUB_FUN'
Writes a workspace root at <dir> whose Cargo.toml lists <member>... as members
and declares each of them under [workspace.dependencies] by its path, the way
a workspace lets a member depend on a sibling with `workspace = true`.

Usage: cargo__fixture_workspace <dir> <member>...
PUB_FUN
cargo__fixture_workspace() {
  __cargo__fixture_workspace__dir="$1"
  shift

  mkdir -p "$__cargo__fixture_workspace__dir"
  {
    printf '[workspace]\n'
    printf 'members = [%s]\n' "$(__cargo__fixture__quoted_list "$@")"
    printf '\n[workspace.dependencies]\n'
    for __cargo__fixture_workspace__member in "$@"; do
      printf '%s = { path = "%s" }\n' \
        "$__cargo__fixture_workspace__member" \
        "$__cargo__fixture_workspace__member"
    done
  } > "$__cargo__fixture_workspace__dir/Cargo.toml"
}

: <<'FUN'
Prints <word>... as a TOML array's contents: each quoted, comma-separated.

    __cargo__fixture__quoted_list a b  ->  "a", "b"
FUN
__cargo__fixture__quoted_list() {
  __cargo__fixture__quoted_list__out=""
  for __cargo__fixture__quoted_list__word in "$@"; do
    __cargo__fixture__quoted_list__out="$__cargo__fixture__quoted_list__out, \"$__cargo__fixture__quoted_list__word\""
  done
  println "${__cargo__fixture__quoted_list__out#, }"
}

: <<'PUB_FUN'
Appends a [<section>] table holding <line>... to the Cargo.toml at <dir>, so a
crate written by cargo__fixture_package gains dependencies:

    cargo__fixture_dependencies "$dir/b" dependencies 'a = { workspace = true }'
    cargo__fixture_dependencies "$dir/c" dev-dependencies 'a = { path = "../a" }'

Usage: cargo__fixture_dependencies <dir> <section> <line>...
PUB_FUN
cargo__fixture_dependencies() {
  __cargo__fixture_dependencies__dir="$1"
  __cargo__fixture_dependencies__section="$2"
  shift 2

  {
    printf '\n[%s]\n' "$__cargo__fixture_dependencies__section"
    println "$@"
  } >> "$__cargo__fixture_dependencies__dir/Cargo.toml"
}

: <<'PUB_FUN'
Writes <version> into <manifest> the way the cargo writer would, so a stubbed
write leaves the crate genuinely modified.

Usage: cargo__fixture_write_version <version> [<manifest>]
PUB_FUN
cargo__fixture_write_version() {
  printf 'version = "%s"\n' "$1" > "${2:-$CARGO_MANIFEST_FILE}"
}

: <<'PUB_FUN'
Refreshes the lockfile beside <manifest>, the file `cargo update` writes.

Usage: cargo__fixture_lock_beside <manifest>
PUB_FUN
cargo__fixture_lock_beside() {
  __cargo__fixture_lock_beside__dir="$(dirname "$1")"
  printf 'locked\n' > "$__cargo__fixture_lock_beside__dir/Cargo.lock"
}
