#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2016

source "$SHELLOPS_DIR/plugins/tools/common.sh"
import "$SHELLOPS_DIR/lib/rust/api.sh"

# shellcheck disable=SC2034  # the usage is the file's doc; the script channel sources it with no arguments
USAGE="$(cat <<'HELP'
rustup absent -> bootstrap rustup + the toolchain + components; present ->
install the toolchain and add any missing components, then select it as the
default and put cargo on PATH (recorded to .ops/cache/env.sh, sourced by .envrc)
so every action and CI step sees the toolchain without per-step PATH patching.

The toolchain is the requirement's override, which `ops install
rustup@<toolchain>` sets (fuzz -> nightly), or else the ops.lock default.
Sourced by the script channel with the requirement in
SHELLOPS_TOOL_REQUIREMENTS; takes no arguments.
HELP
)"

main() {
  rustup__source_cargo_env
  @get __main__default "$SHELLOPS_TOOL_REQUIREMENTS" '.toolchain' 'stable'
  @get __main__toolchain "$SHELLOPS_TOOL_REQUIREMENTS" '.override' "$__main__default"
  @arr __main__none
  @get __main__component_list "$SHELLOPS_TOOL_REQUIREMENTS" '.components' "$__main__none"
  @join __main__components "$__main__component_list" " "

  # shellcheck disable=SC2086  # component names are single tokens, so the word split is intended
  __rustup__ensure "$__main__toolchain" $__main__components
  rustup default "$__main__toolchain"
  __rustup__ensure_path

  shell_rc__offer_line \
    "Rust's cargo environment" \
    'source "$HOME/.cargo/env"'
}

main
