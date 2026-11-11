#!/usr/bin/env bash

: <<'MODULE'
Playwright runner plugin for Test Impact Analysis (TIA): browser and
component tests run by file through the project's own playwright.
MODULE

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/adapter.sh" \
  "$SHELLOPS_DIR/lib/testing/binary.sh"

:<<'FUN'
Reads the suite config's project_dir: the $PROJ-relative directory holding
package.json and node_modules, for a repository whose app lives below the
root. Defaults to the project root.

usage: __testing__frameworks__playwright__project_dir "$suite_cfg"
FUN
__testing__frameworks__playwright__project_dir() {
  @obj __testing__frameworks__playwright__project_dir__obj_1
  @get __testing__frameworks__playwright__project_dir__out "${1:-$__testing__frameworks__playwright__project_dir__obj_1}" '.project_dir' "."
  println "$__testing__frameworks__playwright__project_dir__out"
}

:<<'FUN'
Echoes the playwright binary to run for a project dir: that dir's own
installed copy, then any playwright on PATH, per lib/testing/binary.sh.

usage: __testing__frameworks__playwright__binary "."
FUN
__testing__frameworks__playwright__binary() {
  testing__resolve_binary playwright "$PROJ/$1/node_modules/.bin/playwright"
}

:<<'FUN'
Echoes the --config argument the suite's `config` asks for, as one line per
word so a caller can read it into arguments, or nothing when the suite names
no config and playwright finds its own.

usage: __testing__frameworks__playwright__config_args "$suite_cfg"
FUN
__testing__frameworks__playwright__config_args() {
  @obj __testing__frameworks__playwright__config_args__obj_2
  @get __testing__frameworks__playwright__config_args__path "${1:-$__testing__frameworks__playwright__config_args__obj_2}" '.config' ""
  if @defined "$__testing__frameworks__playwright__config_args__path"; then
    printf -- '--config\n%s\n' "$__testing__frameworks__playwright__config_args__path"
  fi
}

:<<'FUN'
Runs `playwright test` in the suite's project dir with the suite's config and
the arguments given, passing playwright's exit code through. Fails, saying
so, when no playwright binary resolves.

args:
  $1  The effective suite config
  $@  The arguments after `playwright test`
FUN
__testing__frameworks__playwright__run() {
  __testing__frameworks__playwright__run__cfg="$1"
  shift
  __testing__frameworks__playwright__run__dir="$(__testing__frameworks__playwright__project_dir "$__testing__frameworks__playwright__run__cfg")"
  __testing__frameworks__playwright__run__bin="$(__testing__frameworks__playwright__binary "$__testing__frameworks__playwright__run__dir")"
  if ! @defined "$__testing__frameworks__playwright__run__bin"; then
    error "playwright: no playwright binary found"
    return 1
  fi

  mapfile -t __testing__frameworks__playwright__run__config < <(__testing__frameworks__playwright__config_args "$__testing__frameworks__playwright__run__cfg")
  (
    cd "$PROJ/$__testing__frameworks__playwright__run__dir" || exit
    "$__testing__frameworks__playwright__run__bin" test "${__testing__frameworks__playwright__run__config[@]}" "$@"
  )
}

:<<'DOC'
The playwright framework runner; inner @-roles re-home to playwright_<role> on load.
DOC
@runner.playwright() {
  :<<'FUN'
Runs the given $PROJ-relative test files; playwright treats each as a filter
its test files must match, which a full path does exactly. Zero files fail
loudly, so a stale selection never passes silently.
FUN
  @run_selected() {
    __playwright_run_selected__cfg="$1"
    shift
    if [ "$#" -eq 0 ]; then
      error "playwright_run_selected: no test files specified"
      return 1
    fi

    __testing__frameworks__playwright__run "$__playwright_run_selected__cfg" "$@"
  }

  :<<'FUN'
Runs the whole suite, letting the suite's playwright config decide which
files are tests.
FUN
  @run_all() {
    __testing__frameworks__playwright__run "$1"
  }

  :<<'FUN'
The manifest-facing JSON Schema fragment for a playwright suite.
FUN
  @suite_schema() {
    cat "$SHELLOPS_DIR/lib/testing/frameworks/playwright/suite.schema.json"
  }

  :<<'FUN'
The resolver-owned discovery strategies playwright opts into.
FUN
  @strategies() {
    @arr __at_out sibling filename
    println "$__at_out"
  }

  :<<'FUN'
playwright's default suite config: spec files beside the code they test,
named *.spec.ts, run by the project's own playwright with its own config.
FUN
  @suite_defaults() {
    @arr __at3 sibling filename
    @obj __at_out \
      '.runner' "playwright" \
      '.project_dir' "." \
      '.root' "tests" \
      '.glob' "*.spec.ts" \
      '.config' "" \
      '.discovery' "$__at3"
    println "$__at_out"
  }
}

