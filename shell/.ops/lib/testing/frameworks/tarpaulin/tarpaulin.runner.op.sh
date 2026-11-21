#!/usr/bin/env bash

# Tarpaulin runner plugin for Test Impact Analysis (TIA): cargo tests run under
# cargo-tarpaulin, yielding line coverage.

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/rust/tools.sh" \
  "$SHELLOPS_DIR/lib/testing/adapter.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/cargo/cargo.runner.op.sh"

:<<'FUN'
The absolute directory tarpaulin writes its JSON report into: the suite's
report_dir joined under $PROJ. A top-level helper shared by the run roles and
coverage_summary, so the writer and the reader agree on the location.

args:
  $1  The effective suite config
FUN
__testing__frameworks__tarpaulin__report_dir() {
  @get __testing__frameworks__tarpaulin__report_dir__get_1 "$1" '.report_dir' 'target/coverage/tarpaulin'
  printf '%s/%s' "$PROJ" "$__testing__frameworks__tarpaulin__report_dir__get_1"
}

:<<'FUN'
Runs cargo-tarpaulin over the selection given as trailing arguments (-p pairs,
or --workspace), after asserting the tool is provisioned. Tarpaulin's own output
stays on stdout and stderr as the job log; its JSON report lands in the suite's
report directory for coverage_summary to read. Each ignore pattern reaches
tarpaulin as its own --exclude-files glob. Passes the exit code through. A
top-level helper shared by the run roles.

args:
  $1  The effective suite config
  $@  Selection arguments
FUN
__testing__frameworks__tarpaulin__run() {
  __testing__frameworks__tarpaulin__run__cfg="$1"
  shift
  rust__assert_cargo_tool cargo-tarpaulin || return 1

  __testing__frameworks__tarpaulin__run__report_dir="$(__testing__frameworks__tarpaulin__report_dir "$__testing__frameworks__tarpaulin__run__cfg")"
  mkdir -p "$__testing__frameworks__tarpaulin__run__report_dir"

  mapfile -t __testing__frameworks__tarpaulin__run__cargo_args < <(testing__frameworks__cargo__lines "$(testing__frameworks__cargo__extra_args "$__testing__frameworks__tarpaulin__run__cfg")")
  mapfile -t __testing__frameworks__tarpaulin__run__ignores < <(testing__frameworks__cargo__lines "$(testing__frameworks__cargo__ignore_patterns "$__testing__frameworks__tarpaulin__run__cfg")")

  __testing__frameworks__tarpaulin__run__args=(
    tarpaulin
    --engine llvm
    "${__testing__frameworks__tarpaulin__run__cargo_args[@]}"
    --out json
    --output-dir "$__testing__frameworks__tarpaulin__run__report_dir"
  )
  for __testing__frameworks__tarpaulin__run__ignore in "${__testing__frameworks__tarpaulin__run__ignores[@]}"; do
    __testing__frameworks__tarpaulin__run__args+=(--exclude-files "$__testing__frameworks__tarpaulin__run__ignore")
  done

  cargo "${__testing__frameworks__tarpaulin__run__args[@]}" "$@"
}

:<<'DOC'
The tarpaulin runner; inner @-roles re-home to tarpaulin_<role> on load. Package
selection and crate discovery are cargo's, so a tarpaulin suite selects and
discovers exactly as a cargo suite does and differs only in how the run is
instrumented and what it leaves behind.
DOC
@runner.tarpaulin() {
  :<<'FUN'
Runs the packages owning the selected files (each a $PROJ-relative path) under
tarpaulin, in the workspace named by the suite config. With no member left to
select, measures the whole workspace. Passes the exit code through.
FUN
  @run_selected() {
    __tarpaulin_run_selected__cfg="$1"
    shift
    __tarpaulin_run_selected__packages="$(testing__frameworks__cargo__selected_packages "$__tarpaulin_run_selected__cfg" "$@")" || return 1

    mapfile -t __tarpaulin_run_selected__args < <(
      testing__frameworks__cargo__manifest_args "$__tarpaulin_run_selected__cfg"
      testing__frameworks__cargo__package_args "$__tarpaulin_run_selected__packages"
    )
    if @len __at2 "$__tarpaulin_run_selected__packages"; [ "$__at2" -eq 0 ]; then
      __tarpaulin_run_selected__args+=(--workspace)
    fi

    __testing__frameworks__tarpaulin__run "$__tarpaulin_run_selected__cfg" "${__tarpaulin_run_selected__args[@]}"
  }

  :<<'FUN'
Measures the whole workspace named by the suite config under tarpaulin, passing
the exit code through.
FUN
  @run_all() {
    mapfile -t __tarpaulin_run_all__args < <(testing__frameworks__cargo__manifest_args "$1")
    __testing__frameworks__tarpaulin__run "$1" --workspace "${__tarpaulin_run_all__args[@]}"
  }

  :<<'FUN'
The manifest-facing JSON Schema fragment for a tarpaulin suite.
FUN
  @suite_schema() {
    cat "$SHELLOPS_DIR/lib/testing/frameworks/tarpaulin/suite.schema.json"
  }

  :<<'FUN'
The discovery strategies cargo opts into; a tarpaulin suite is a cargo suite for
discovery purposes.
FUN
  @strategies() {
    cargo_strategies
  }

  :<<'FUN'
cargo's default suite config under this runner's id, with the report written to
target/coverage/tarpaulin and the instrumented run made with
--no-default-features --locked.
FUN
  @suite_defaults() {
    @arr __at3 --no-default-features --locked
    @set __at_out "$(cargo_suite_defaults)" \
      '.runner' "tarpaulin" \
      '.report_dir' "target/coverage/tarpaulin" \
      '.cargo_args' "$__at3"
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
Prints the last run's coverage report, normalized to the shape lib/coverage/api.sh
works on (metric "lines"), with every file attributed to the suite the config
names (defaulting to this runner's id). Fails when no report exists yet.

args:
  $1  The effective suite config
FUN
  @coverage_summary() {
    __tarpaulin_coverage_summary__report="$(__testing__frameworks__tarpaulin__report_dir "$1")/tarpaulin-report.json"
    if [ ! -f "$__tarpaulin_coverage_summary__report" ]; then
      error "tarpaulin: no report at $__tarpaulin_coverage_summary__report; run the suite first"
      return 1
    fi

    @get __at4 "$1" '.suite' 'tarpaulin'
    @run_awk __at_out "$SHELLOPS_DIR/lib/testing/frameworks/tarpaulin/report.awk" \
      "$(cat "$__tarpaulin_coverage_summary__report")" \
      --arg root "$PROJ" \
      --arg suite "$__at4" \
      --load "$SHELLOPS_DIR/lib/coverage/coverage.awk" || return 1
    println "$__at_out"
  }
}

# Desugar @runner.tarpaulin into the flat tarpaulin_<role> functions, then
# register under "tarpaulin". Guarded so a re-import sources the interpreter,
# desugars, and registers at most once.
command -v interpreter__load_runner >/dev/null 2>&1 \
  || import "$SHELLOPS_DIR/interpreter/api.sh"
command -v tarpaulin_run_selected >/dev/null 2>&1 \
  || interpreter__load_runner tarpaulin @runner.tarpaulin
@is_true "$(testing__adapter_registered tarpaulin)" || testing__register_adapter tarpaulin
