#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/cargo/cargo.runner.op.sh"

:<<'FRAGMENT'
What a doctest run of a suite leaves behind: the report directory, the JUnit
path the escape join reads, and the translation of libtest's text output into
that report, each doctest keyed by its repo-relative file.
FRAGMENT

__testing__frameworks__rust_doctest__DIR="$SHELLOPS_DIR/lib/testing/frameworks/rust_doctest"

:<<'FUN'
The absolute directory a run of the suite leaves its report in: target/rust_doctest
under the workspace's target directory (CARGO_TARGET_DIR when set). Holds the
run's own output as run.log and the JUnit translated from it as junit.xml. A
top-level helper shared by the run and the report path.

args:
  $1  The effective suite config
FUN
__testing__frameworks__rust_doctest__report_dir() {
  printf '%s/rust_doctest' "${CARGO_TARGET_DIR:-$(testing__frameworks__cargo__workspace_root "$1")/target}"
}

:<<'FUN'
The absolute path of the JUnit report a run of the suite leaves behind. This is
the path the escape join reads, so the writer and the reader agree on it here.

args:
  $1  The effective suite config
FUN
__testing__frameworks__rust_doctest__junit_path() {
  printf '%s/junit.xml' "$(__testing__frameworks__rust_doctest__report_dir "$1")"
}

:<<'FUN'
The crate directories junit.awk needs to spell a doctest's file repo-relative,
as "<crate>=<dir>" pairs separated by spaces, one per tracked package.

  __testing__frameworks__rust_doctest__package_roots_map  ->  "errors=engine/errors opcache=engine/cache"
FUN
__testing__frameworks__rust_doctest__package_roots_map() {
  @map __testing__frameworks__rust_doctest__package_roots_map__map_1 __testing__frameworks__rust_doctest__root_pair "$(testing__frameworks__cargo__package_roots)"
  @join __testing__frameworks__rust_doctest__package_roots_map__out "$__testing__frameworks__rust_doctest__package_roots_map__map_1" ' '
  println "$__testing__frameworks__rust_doctest__package_roots_map__out"
}

:<<'FUN'
@map callback: one package directory as its "<crate>=<dir>" pair.

args:
  $1  Package directory (wrapped)
FUN
__testing__frameworks__rust_doctest__root_pair() {
  @unwrap __testing__frameworks__rust_doctest__root_pair__dir "$1"
  printf '%s=%s' \
    "$(toml__get "$PROJ/$__testing__frameworks__rust_doctest__root_pair__dir/Cargo.toml" package name)" \
    "$__testing__frameworks__rust_doctest__root_pair__dir"
}

:<<'FUN'
Translates results.awk's lines on stdin into the JUnit report, with the crate
directories bound so every classname is repo-relative.
FUN
__testing__frameworks__rust_doctest__junit() {
  awk \
    -f "$__testing__frameworks__rust_doctest__DIR/paths.awk" \
    -f "$__testing__frameworks__rust_doctest__DIR/junit.awk" \
    -v roots="$(__testing__frameworks__rust_doctest__package_roots_map)"
}
