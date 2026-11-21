#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/cargo/api.sh" \
  "$SHELLOPS_DIR/lib/self/api.sh" \
  "$SHELLOPS_DIR/lib/rust/tools.sh" \
  "$SHELLOPS_DIR/lib/rustup/api.sh"

: <<'MODULE'
The Rust module, importable on its own: a caller reaches every rust_<op> from
this file. The toolchain's homes and installers live in lib/rustup/api.sh and
tool presence is asserted by lib/rust/tools.sh; the cargo checks CI runs over a
workspace are defined here. Fuzzing and coverage are TIA runner concerns: see
lib/testing/frameworks/{fuzz,tarpaulin,llvm_cov} and lib/coverage/api.sh.
MODULE

rust__fmt_check() {
  cargo fmt --all -- --check
}

rust__clippy_workspace() {
  cargo clippy --workspace --all-targets --no-default-features --locked -- -D warnings
}

rust__test_workspace() {
  cargo test --workspace --no-default-features --locked
}

rust__audit() {
  rust__assert_cargo_tool cargo-audit || return 1
  cargo audit
}

: <<'PUB_FUN'
Returns the platform-appropriate shared library filename for a given name.

  rust__shared_lib_filename godot
  # => libgodot.so  (Linux)
  # => libgodot.dylib (macOS)
PUB_FUN
rust__shared_lib_filename() {
  case "$(uname -s)" in
    Darwin) echo "lib${1}.dylib" ;;
    *)      echo "lib${1}.so" ;;
  esac
}
