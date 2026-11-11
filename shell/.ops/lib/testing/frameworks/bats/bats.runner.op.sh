#!/usr/bin/env bash

# Bats runner plugin for Test Impact Analysis (TIA).

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/adapter.sh" \
  "$SHELLOPS_DIR/lib/testing/binary.sh"

:<<'FUN'
Echoes the bats binary to run: the project's vendored copy, then shellops'
own, then any bats on PATH, per lib/testing/binary.sh. A top-level helper
shared by the run_* roles, not a contract role.
FUN
__testing__frameworks__bats__binary() {
  testing__resolve_binary bats \
    "$PROJ/test/lib/bats-core/bin/bats" \
    "$SHELLOPS_DIR/test/lib/bats-core/bin/bats"
}

:<<'FUN'
Echoes how many tests the suite runs at once, from the suite config's `jobs`,
or 1 when it names none. A top-level helper shared by the run_* roles, not a
contract role.

  __testing__frameworks__bats__jobs '{"jobs":24}'  ->  24
  __testing__frameworks__bats__jobs '{}'           ->  1

One is bats's own serial path and needs no GNU parallel, so a suite that names
no count runs exactly as it did before anyone chose one.
FUN
__testing__frameworks__bats__jobs() {
  @get __testing__frameworks__bats__jobs__out "$1" '.jobs' 1
  println "$__testing__frameworks__bats__jobs__out"
}

:<<'FUN'
Echoes how many seconds one test may run before bats fails it, from the
suite config's `test_timeout_secs`, or 600 when it names none. A test that
hangs then fails by name, instead of holding the job until the job's own
timeout ends it with nothing in the log to say which test it was.

  __testing__frameworks__bats__test_timeout '{"test_timeout_secs":30}'  ->  30
  __testing__frameworks__bats__test_timeout '{}'                        ->  600
FUN
__testing__frameworks__bats__test_timeout() {
  @get __testing__frameworks__bats__test_timeout__out "$1" '.test_timeout_secs' 600
  println "$__testing__frameworks__bats__test_timeout__out"
}

:<<'FUN'
Runs bats over the given files with the suite config's job count and
per-test timeout, and passes bats's exit code through.

  $1 suite config   $2.. the test files
FUN
__testing__frameworks__bats__run_files() {
  __testing__frameworks__bats__run_files__cfg="$1"
  shift
  __testing__frameworks__bats__run_files__jobs="$(__testing__frameworks__bats__jobs "$__testing__frameworks__bats__run_files__cfg")"
  __testing__frameworks__bats__run_files__timeout="$(__testing__frameworks__bats__test_timeout "$__testing__frameworks__bats__run_files__cfg")"

  __testing__frameworks__bats__run_files__bin="$(__testing__frameworks__bats__binary)"
  if ! @defined "$__testing__frameworks__bats__run_files__bin"; then
    error "bats: no bats binary found"
    return 1
  fi

  BATS_TEST_TIMEOUT="$__testing__frameworks__bats__run_files__timeout" \
    "$__testing__frameworks__bats__run_files__bin" \
    --jobs "$__testing__frameworks__bats__run_files__jobs" \
    "$@"
}

:<<'DOC'
The bats framework runner; inner @-roles re-home to bats_<role> on load.
DOC
@runner.bats() {
  :<<'FUN'
Runs bats against the given $PROJ-relative test files, passing its exit
code. bats runs exactly the files it is handed, as many at a time as the
suite config's `jobs` names, each test bounded by the config's
`test_timeout_secs`. The dispatcher deals a parallel job's share of a suite
before it gets here (lib/testing/dispatch.sh).
FUN
  @run_selected() {
    if [ "$#" -lt 2 ]; then
      error "bats_run_selected: no test files specified"
      return 1
    fi
    __testing__frameworks__bats__run_files "$@"
  }

  :<<'FUN'
Runs the whole bats suite under $PROJ/test, skipping vendored libs and
hidden paths, as many tests at a time as the suite config's `jobs` names,
each test bounded by the config's `test_timeout_secs`. A hidden path is one
whose own name begins with a dot, so a project checked out below a dotted
directory is not mistaken for one and left with nothing to run.
FUN
  @run_all() {
    if [ ! -d "$PROJ/test" ]; then
      error "bats_run_all: no test directory at $PROJ/test"
      return 1
    fi

    __bats_run_all__cfg="$1"
    __bats_run_all__files="$(find "$PROJ/test" \
      \( -name '.*' -o -path '*/lib/bats-*' \) -prune \
      -o -type f -name '*.bats' -print \
      | sort
    )"
    set --
    while IFS= read -r __bats_run_all__file; do
      if @defined "$__bats_run_all__file"; then
        set -- "$@" "$__bats_run_all__file"
      fi
    done <<EOF
$__bats_run_all__files
EOF
    __testing__frameworks__bats__run_files "$__bats_run_all__cfg" "$@"
  }

  :<<'FUN'
The manifest-facing JSON Schema fragment for a bats suite.
FUN
  @suite_schema() {
    cat "$SHELLOPS_DIR/lib/testing/frameworks/bats/suite.schema.json"
  }

  :<<'FUN'
The resolver-owned discovery strategies bats opts into.
FUN
  @strategies() {
    @arr __at_out sibling filename
    println "$__at_out"
  }

  :<<'FUN'
bats's default suite config, used when a manifest sets no overrides.
FUN
  @suite_defaults() {
    @arr __at1 sibling filename
    @obj __at_out \
      '.runner' "bats" \
      '.root' "test" \
      '.glob' "*.bats" \
      '.discovery' "$__at1"
    println "$__at_out"
  }
}

# Desugar @runner.bats into the flat bats_<role> functions, then register under
# "bats". Guarded so a re-import sources the interpreter, desugars, and registers
# at most once.
command -v interpreter__load_runner >/dev/null 2>&1 \
  || import "$SHELLOPS_DIR/interpreter/api.sh"
command -v bats_run_selected >/dev/null 2>&1 \
  || interpreter__load_runner bats @runner.bats
@is_true "$(testing__adapter_registered bats)" || testing__register_adapter bats
