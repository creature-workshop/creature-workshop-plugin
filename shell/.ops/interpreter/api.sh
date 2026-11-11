#!/usr/bin/env bash

# shellops bash op interpreter: loads and runs .op.sh ops directly, and
# introspects them via load_ops/interpreter__load_type to emit the registry the engine
# consumes. Distinct from the engine, which compiles .ops to POSIX sh. Ops and
# types are discovered from builtins/ (global) and lib/ (opt-in). Authoring
# surface:
#   @in.type  → declare typed inputs at load time
#   @in name  → retrieve raw bound input at runtime
#   @out.type → declare output fields at load time / build them at runtime
# Primitive types are NOT defined here; they are global @type decls in
# builtins/ (string, int, bool, …), discovered like any other op/type.
#
# This file is a thin sourcing barrel. The implementation is split by concern
# into the sibling files sourced below; consumers source only this file. Order
# matters in one place: registry_state.sh runs at source time (it declares the
# global registry arrays + interpreter state), so it must come first. Every
# other fragment only defines functions, so their order is logical, not
# load-bearing.

__interpreter_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The interpreter builds its values with the structs verbs, which run on the
# SILT library that .envrc loads. A caller that sourced .envrc has both, and
# a caller that came another way gets them here.
if ! command -v @defined >/dev/null 2>&1; then
  SHELLOPS_DIR="${SHELLOPS_DIR:-$(cd "$__interpreter_dir/.." && pwd)}"
  # shellcheck source=../.envrc
  source "$SHELLOPS_DIR/.envrc"
fi

# shellcheck source=registry_state.sh
source "$__interpreter_dir/registry_state.sh"
# shellcheck source=op_api.sh
source "$__interpreter_dir/op_api.sh"
# shellcheck source=typed_io.sh
source "$__interpreter_dir/typed_io.sh"
# shellcheck source=discovery.sh
source "$__interpreter_dir/discovery.sh"
# shellcheck source=dispatch.sh
source "$__interpreter_dir/dispatch.sh"
# shellcheck source=registry_json.sh
source "$__interpreter_dir/registry_json.sh"

unset __interpreter_dir
