#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/self/assert.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Asserting that provisioned Rust tooling is present.

Cargo tools and rustup components are pinned in ops.lock and installed by
`ops install` (lib/self/assert.sh owns the assert-don't-build rationale).
rust__assert_rustup_component keeps its own hint block: it suggests editing the
components array inside the existing rustup entry, not adding a whole entry,
which is a shape self__hint_lock_entry does not render.
MODULE

: <<'PUB_FUN'
Asserts that a cargo tool is available. Returns 1 with a hint pointing at the
ops.lock entry that provisions it if it is missing.

  rust__assert_cargo_tool cargo-tarpaulin
PUB_FUN
rust__assert_cargo_tool() {
  __rust__assert_cargo_tool__crate="${1:?usage: rust__assert_cargo_tool <crate>}"

  @obj __rust__assert_cargo_tool__obj_1 '.version' '<version>' '.args' '--disable-strategies compile'
  self__assert_tool \
    "$__rust__assert_cargo_tool__crate" \
    cargo-binstall \
    "$__rust__assert_cargo_tool__obj_1"
}

: <<'PUB_FUN'
Asserts that a rustup component is installed on the active toolchain. Returns 1
with a hint pointing at the ops.lock rustup entry that provisions it if it is
missing. Matches on the component's bare name, so `llvm-tools` is satisfied by
the target-suffixed `llvm-tools-x86_64-unknown-linux-gnu` rustup lists.

  rust__assert_rustup_component llvm-tools
PUB_FUN
rust__assert_rustup_component() {
  __rust__assert_rustup_component__name="${1:?usage: rust__assert_rustup_component <component>}"

  if rustup component list --installed 2>/dev/null | grep -q "^$__rust__assert_rustup_component__name"; then
    return 0
  fi

  error "rustup component $__rust__assert_rustup_component__name is not installed"
  hint "Provision it with: shell/ops install rustup"
  hint ""
  hint "Add it to the rustup entry in your ops.lock first:"
  hint ""
  hint '  "script": {'
  hint '    "rustup": {'
  hint "      \"components\": [\"rustfmt\", \"clippy\", \"$__rust__assert_rustup_component__name\"]"
  hint '    }'
  hint '  }'
  return 1
}
