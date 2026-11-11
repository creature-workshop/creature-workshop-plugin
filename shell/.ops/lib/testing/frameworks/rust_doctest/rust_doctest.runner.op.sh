#!/usr/bin/env bash

# Doctest runner plugin for Test Impact Analysis (TIA): a workspace's doctests
# run with cargo test --doc, always in full, leaving a JUnit report behind. The
# helpers it calls live beside it by concern: report.sh and run.sh.

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/cargo/cargo.runner.op.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/rust_doctest/report.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/rust_doctest/run.sh"

:<<'DOC'
The rust_doctest runner; inner @-roles re-home to rust_doctest_<role> on load. Every run
is the whole workspace's doctests, since stable Rust cannot select or filter
them; what selection decides is whether the lane runs at all, and the record
lists the Rust sources the selection touched. Discovery is cargo's package
walk, so planning never compiles anything; the JUnit the run leaves keys each
doctest by its repo-relative file, so the escape join reads it under its
default, file-path, against those sources.
DOC
@runner.rust_doctest() {
  :<<'FUN'
Runs every doctest in the workspace named by the suite config, whatever files
(each a $PROJ-relative path) the selection picked. Passes the cargo exit code
through.
FUN
  @run_selected() {
    __testing__frameworks__rust_doctest__run "$1"
  }

  :<<'FUN'
Runs every doctest in the workspace named by the suite config, passing the
cargo exit code through.
FUN
  @run_all() {
    __testing__frameworks__rust_doctest__run "$1"
  }

  :<<'FUN'
The manifest-facing JSON Schema fragment for a doctest suite.
FUN
  @suite_schema() {
    cat "$__testing__frameworks__rust_doctest__DIR/suite.schema.json"
  }

  :<<'FUN'
The discovery strategies cargo opts into; a doctest suite is a cargo suite for
discovery purposes, its doctests living in the package-owned Rust sources.
FUN
  @strategies() {
    cargo_strategies
  }

  :<<'FUN'
cargo's default suite config under this runner's id.
FUN
  @suite_defaults() {
    @set __at_out "$(cargo_suite_defaults)" '.runner' "rust_doctest"
    println "$__at_out"
  }

  :<<'FUN'
cargo's "native" discovery for every area at once.
FUN
  @discover_all() {
    cargo_discover_all "$@"
  }

  :<<'FUN'
cargo's "native" discovery for a single area.
FUN
  @discover() {
    cargo_discover "$@"
  }

  :<<'FUN'
The JUnit report a run of the suite leaves behind.

args:
  $1  The effective suite config
FUN
  @junit_path() {
    __testing__frameworks__rust_doctest__junit_path "$1"
  }
}
