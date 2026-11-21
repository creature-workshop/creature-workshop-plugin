#!/usr/bin/env bash

: <<'MODULE'
node:test runner plugin for Test Impact Analysis (TIA): Node's own test
runner, `node --test`, over the files named.
MODULE

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/adapter.sh" \
  "$SHELLOPS_DIR/lib/testing/binary.sh"

:<<'FUN'
Reads the suite config's project_dir: the $PROJ-relative directory the tests
resolve their imports from. Defaults to the project root.

usage: __testing__frameworks__node_test__project_dir "$suite_cfg"
FUN
__testing__frameworks__node_test__project_dir() {
  @obj __testing__frameworks__node_test__project_dir__obj_1
  @get __testing__frameworks__node_test__project_dir__out "${1:-$__testing__frameworks__node_test__project_dir__obj_1}" '.project_dir' "."
  println "$__testing__frameworks__node_test__project_dir__out"
}

:<<'FUN'
Echoes the node binary to run: any node on PATH, per lib/testing/binary.sh.
Node is never vendored under node_modules, so PATH is the only candidate.

usage: __testing__frameworks__node_test__binary
FUN
__testing__frameworks__node_test__binary() {
  testing__resolve_binary node
}

:<<'FUN'
Runs `node --test` in the suite's project dir over the files given, passing
node's exit code through. Fails, saying so, when no node resolves.

args:
  $1  The effective suite config
  $@  The $PROJ-relative test files
FUN
__testing__frameworks__node_test__run() {
  __testing__frameworks__node_test__run__cfg="$1"
  shift
  __testing__frameworks__node_test__run__bin="$(__testing__frameworks__node_test__binary)"
  if ! @defined "$__testing__frameworks__node_test__run__bin"; then
    error "node_test: no node binary found"
    return 1
  fi

  (
    cd "$PROJ/$(__testing__frameworks__node_test__project_dir "$__testing__frameworks__node_test__run__cfg")" || exit
    "$__testing__frameworks__node_test__run__bin" --test "$@"
  )
}

:<<'FUN'
Echoes the suite's test files for a whole run, one per line: the files under
the suite's root whose name matches its glob, skipping node_modules and hidden
paths, in sorted order.

args:
  $1  The effective suite config
FUN
__testing__frameworks__node_test__all_files() {
  @get __testing__frameworks__node_test__all_files__root "$1" '.root' '.'
  (
    cd "$PROJ" || exit
    @get __testing__frameworks__node_test__all_files__get_2 "$1" '.glob' '*.test.js'
    find "$__testing__frameworks__node_test__all_files__root" -mindepth 1 \
      \( -name '.*' -o -name node_modules \) -prune \
      -o -type f -name "$__testing__frameworks__node_test__all_files__get_2" -print \
      | sed 's|^\./||' \
      | LC_ALL=C sort
  )
}

:<<'FUN'
Runs the whole suite: every file under the suite's root that matches its
glob. Fails when there is none, since a suite with no tests is a
misconfiguration and not a pass. A top-level helper the run_all role calls.

args:
  $1  The effective suite config
FUN
__testing__frameworks__node_test__run_whole() {
  mapfile -t __testing__frameworks__node_test__run_whole__files < <(__testing__frameworks__node_test__all_files "$1")
  if [ "${#__testing__frameworks__node_test__run_whole__files[@]}" -eq 0 ]; then
    @get __testing__frameworks__node_test__run_whole__get_3 "$1" '.root' '.'
    @get __testing__frameworks__node_test__run_whole__get_4 "$1" '.glob' '*.test.js'
    error "node_test_run_all: no test files under $__testing__frameworks__node_test__run_whole__get_3 match $__testing__frameworks__node_test__run_whole__get_4"
    return 1
  fi

  __testing__frameworks__node_test__run "$1" "${__testing__frameworks__node_test__run_whole__files[@]}"
}

:<<'DOC'
The node_test framework runner; inner @-roles re-home to node_test_<role> on load.
DOC
@runner.node_test() {
  :<<'FUN'
Runs the given $PROJ-relative test files through `node --test`. Zero files
fail loudly, so a stale selection never passes silently.
FUN
  @run_selected() {
    __node_test_run_selected__cfg="$1"
    shift
    if [ "$#" -eq 0 ]; then
      error "node_test_run_selected: no test files specified"
      return 1
    fi

    __testing__frameworks__node_test__run "$__node_test_run_selected__cfg" "$@"
  }

  :<<'FUN'
Runs the whole suite: every file under the suite's root that matches its
glob, and fails when there is none.
FUN
  @run_all() {
    __testing__frameworks__node_test__run_whole "$1"
  }

  :<<'FUN'
The manifest-facing JSON Schema fragment for a node_test suite.
FUN
  @suite_schema() {
    cat "$SHELLOPS_DIR/lib/testing/frameworks/node_test/suite.schema.json"
  }

  :<<'FUN'
The resolver-owned discovery strategies node_test opts into.
FUN
  @strategies() {
    @arr __at_out sibling filename
    println "$__at_out"
  }

  :<<'FUN'
node_test's default suite config: *.test.js files anywhere under the root,
beside the code they test.
FUN
  @suite_defaults() {
    @arr __at5 sibling filename
    @obj __at_out \
      '.runner' "node_test" \
      '.project_dir' "." \
      '.root' "." \
      '.glob' "*.test.js" \
      '.discovery' "$__at5"
    println "$__at_out"
  }
}

