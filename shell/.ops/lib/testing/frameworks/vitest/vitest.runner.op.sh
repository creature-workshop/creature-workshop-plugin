#!/usr/bin/env bash

# Vitest runner plugin for Test Impact Analysis (TIA).

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/adapter.sh" \
  "$SHELLOPS_DIR/lib/testing/binary.sh" \
  "$SHELLOPS_DIR/lib/testing/resolver.sh"

:<<'FUN'
Reads the suite config's project_dir -- the $PROJ-relative directory holding
package.json and the vitest config, for repos whose app lives below the
root. Defaults to the project root.

usage: __testing__frameworks__vitest__project_dir "$suite_cfg"
FUN
__testing__frameworks__vitest__project_dir() {
  @obj __testing__frameworks__vitest__project_dir__obj_1
  @get __testing__frameworks__vitest__project_dir__out "${1:-$__testing__frameworks__vitest__project_dir__obj_1}" '.project_dir' "."
  println "$__testing__frameworks__vitest__project_dir__out"
}

:<<'FUN'
Echoes the vitest binary to run for a project dir: that dir's own installed
copy, then any vitest on PATH, per lib/testing/binary.sh. A top-level helper
shared by the run_* and discover roles, not a contract role.

usage: __testing__frameworks__vitest__binary "."
FUN
__testing__frameworks__vitest__binary() {
  testing__resolve_binary vitest "$PROJ/$1/node_modules/.bin/vitest"
}

:<<'FUN'
The test files vitest itself would run, as a struct array of $PROJ-relative
paths -- vitest's own discovery (`vitest list --filesOnly`), asked from the
project root so what TIA maps and what `run` executes can never disagree.
Fails (returns 1, echoing nothing) when vitest is missing or the listing
fails, so a broken listing reads as a failure rather than as "no tests".

  __testing__frameworks__vitest__listed_files  ->  ["src/app/sky.config.test.ts", ...]
FUN
__testing__frameworks__vitest__listed_files() {
  __testing__frameworks__vitest__listed_files__bin="$(__testing__frameworks__vitest__binary ".")"
  if ! @defined "$__testing__frameworks__vitest__listed_files__bin"; then
    error "vitest discovery: no vitest binary found"
    return 1
  fi

  __testing__frameworks__vitest__listed_files__out="$(
    cd "$PROJ" \
      && "$__testing__frameworks__vitest__listed_files__bin" list --filesOnly
  )" || return 1
  @split __testing__frameworks__vitest__listed_files__out "$__testing__frameworks__vitest__listed_files__out"
  println "$__testing__frameworks__vitest__listed_files__out"
}

:<<'DOC'
The vitest framework runner; inner @-roles re-home to vitest_<role> on load.
DOC
@runner.vitest() {
  :<<'FUN'
Runs vitest against the given $PROJ-relative test files, passing its exit
code. Runs from the suite's project dir so vitest resolves the project's own
config; the files still select correctly from there because vitest treats
them as path substring filters. Zero matches fail loudly, so a stale
selection never passes silently.
FUN
  @run_selected() {
    __vitest_run_selected__dir="$(__testing__frameworks__vitest__project_dir "${1:-}")"
    shift
    if [ "$#" -eq 0 ]; then
      error "vitest_run_selected: no test files specified"
      return 1
    fi

    __vitest_run_selected__bin="$(__testing__frameworks__vitest__binary "$__vitest_run_selected__dir")"
    if ! @defined "$__vitest_run_selected__bin"; then
      error "vitest_run_selected: no vitest binary found"
      return 1
    fi

    (
      cd "$PROJ/$__vitest_run_selected__dir" || exit
      "$__vitest_run_selected__bin" run "$@"
    )
  }

  :<<'FUN'
Runs the whole vitest suite from the suite's project dir, letting the
project's own config decide which files are tests.
FUN
  @run_all() {
    __vitest_run_all__dir="$(__testing__frameworks__vitest__project_dir "${1:-}")"

    __vitest_run_all__bin="$(__testing__frameworks__vitest__binary "$__vitest_run_all__dir")"
    if ! @defined "$__vitest_run_all__bin"; then
      error "vitest_run_all: no vitest binary found"
      return 1
    fi

    (
      cd "$PROJ/$__vitest_run_all__dir" || exit
      "$__vitest_run_all__bin" run
    )
  }

  :<<'FUN'
The manifest-facing JSON Schema fragment for a vitest suite.
FUN
  @suite_schema() {
    cat "$SHELLOPS_DIR/lib/testing/frameworks/vitest/suite.schema.json"
  }

  :<<'FUN'
The discovery strategy vitest opts into beyond "default": the common
"native", delegating "what is a test file?" to the framework itself.
FUN
  @strategies() {
    @arr __at_out native
    println "$__at_out"
  }

  :<<'FUN'
vitest's default suite config. Discovery is native, so the project's own
vitest config stays the single answer to what counts as a test; TIA adds
only the area mapping.
FUN
  @suite_defaults() {
    @arr __at2 native
    @obj __at_out \
      '.runner' "vitest" \
      '.project_dir' "." \
      '.discovery' "$__at2"
    println "$__at_out"
  }

  :<<'FUN'
The "native" discovery strategy for every area at once: asks vitest for its
test files and keys them by area coverage via testing__files_by_area. Any
other strategy returns {}. Asks the repo root's vitest -- a below-root
project_dir runs its suite but does not yet feed discovery (OPS-436).

  vitest_discover_all native '{"panorama": ["src/lib/gl"]}' '[]' '[]'
  -> {"panorama": ["src/lib/gl/uniforms.test.ts"]}

args:
  $1  Strategy
  $2  Paths by area ({<area>: [<path>, ...]})
  $3  Globs (unused -- vitest's include is the rule)
  $4  Excludes (unused)
FUN
  @discover_all() {
    if [ "$1" != "native" ]; then
      @obj __at_out
      println "$__at_out"
      return 0
    fi

    __vitest_discover_all__files="$(__testing__frameworks__vitest__listed_files)" || return 1
    testing__files_by_area "$__vitest_discover_all__files" "$2"
  }

  :<<'FUN'
The "native" discovery strategy for a single area. Wraps the area's paths as
a one-entry map, resolves it through vitest_discover_all, and returns that
one answer, so both entry points follow the same rule. Any other strategy
returns [].

args:
  $1  Strategy
  $2  Paths (struct array)
  $3  Globs (unused)
  $4  Excludes (unused)
FUN
  @discover() {
    @obj __at3 '.area' "$2"
    __vitest_discover__derived="$(vitest_discover_all \
      "$1" \
      "$__at3" \
      "$3" \
      "$4"
    )" || return 1
    @arr __at4
    @get __at5 "$__vitest_discover__derived" '.area' "$__at4"
    @compact __at_out "$__at5"
    println "$__at_out"
  }
}

# Desugar @runner.vitest into the flat vitest_<role> functions, then register
# under "vitest". Guarded so a re-import sources the interpreter, desugars, and
# registers at most once.
command -v interpreter__load_runner >/dev/null 2>&1 \
  || import "$SHELLOPS_DIR/interpreter/api.sh"
command -v vitest_run_selected >/dev/null 2>&1 \
  || interpreter__load_runner vitest @runner.vitest
@is_true "$(testing__adapter_registered vitest)" || testing__register_adapter vitest
