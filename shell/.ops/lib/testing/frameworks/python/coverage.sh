#!/usr/bin/env bash

: <<'MODULE'
What the unittest and pytest runners share: the suite config's project dir,
interpreter and coverage sources, the run under coverage.py that writes the
JSON report, and the report normalized to the shape lib/coverage/api.sh gates
on. A runner adds the framework's own arguments and its suite schema.
MODULE

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/coverage/api.sh" \
  "$SHELLOPS_DIR/lib/testing/adapter.sh" \
  "$SHELLOPS_DIR/lib/testing/binary.sh"

:<<'FUN'
Reads the suite config's project_dir: the $PROJ-relative directory the tests
import from and run in, for a repository whose Python lives below the root.
Defaults to the project root.

usage: __testing__frameworks__python__project_dir "$suite_cfg"
FUN
__testing__frameworks__python__project_dir() {
  @obj __testing__frameworks__python__project_dir__obj_1
  @get __testing__frameworks__python__project_dir__out "${1:-$__testing__frameworks__python__project_dir__obj_1}" '.project_dir' "."
  println "$__testing__frameworks__python__project_dir__out"
}

:<<'FUN'
Echoes the interpreter the suite runs under, from the suite config's
`interpreter`, or python3 when it names none. The value may be several words,
such as "uv run python", so callers expand it unquoted.

usage: __testing__frameworks__python__interpreter "$suite_cfg"
FUN
__testing__frameworks__python__interpreter() {
  @obj __testing__frameworks__python__interpreter__obj_2
  @get __testing__frameworks__python__interpreter__out "${1:-$__testing__frameworks__python__interpreter__obj_2}" '.interpreter' "python3"
  println "$__testing__frameworks__python__interpreter__out"
}

:<<'FUN'
Echoes the packages the suite measures coverage over, comma-joined for
coverage.py's --source, or nothing when the suite names none, in which case
the tests run without coverage.

  __testing__frameworks__python__sources '{"source": ["workshop", "dashboard"]}'  ->  workshop,dashboard
FUN
__testing__frameworks__python__sources() {
  @obj __testing__frameworks__python__sources__obj_3
  @arr __testing__frameworks__python__sources__arr_4
  @get __testing__frameworks__python__sources__get_5 "${1:-$__testing__frameworks__python__sources__obj_3}" '.source' "$__testing__frameworks__python__sources__arr_4"
  @join __testing__frameworks__python__sources__out "$__testing__frameworks__python__sources__get_5" ","
  println "$__testing__frameworks__python__sources__out"
}

:<<'FUN'
The absolute path coverage.py writes the suite's JSON report to: coverage.json
inside the suite's report_dir, joined under $PROJ. Shared by the run roles and
coverage_summary, so the writer and the reader agree on the location. The
default keeps the runner's id in the path, so two suites of the two runners
never write over each other's report.

args:
  $1  The effective suite config
FUN
__testing__frameworks__python__report_path() {
  @get __testing__frameworks__python__report_path__get_6 "$1" '.runner' python
  @get __testing__frameworks__python__report_path__get_7 "$1" '.report_dir' ".ops/cache/coverage/$__testing__frameworks__python__report_path__get_6"
  printf '%s/%s/coverage.json' "$PROJ" "$__testing__frameworks__python__report_path__get_7"
}

:<<'FUN'
Prints a file's path relative to the workspace root: coverage.py spells it
relative to where it ran, the suite's project dir, which is put in front of
it unless that is the root.

  __testing__frameworks__python__rooted app workshop/plan.py  ->  app/workshop/plan.py
  __testing__frameworks__python__rooted . workshop/plan.py    ->  workshop/plan.py
FUN
__testing__frameworks__python__rooted() {
  case "$1" in
    .|"") println "$2" ;;
    *) println "$1/$2" ;;
  esac
}

:<<'FUN'
@reduce callback: writes one file of coverage.py's report into the report's
files object, keyed by its workspace-relative path, as a coverage__file_entry
attributed to the suite and this runner.

args:
  $1  The files object so far
  $2  One entry of coverage.py's files: {key: <path>, value: {summary: {covered_lines, num_statements}}}
  $3  The suite's project dir
  $4  The suite's name
  $5  The runner's id, unittest or pytest
FUN
__testing__frameworks__python__file_entry() {
  @get __testing__frameworks__python__file_entry__get_8 "$2" '.key'
  __testing__frameworks__python__file_entry__path="$(__testing__frameworks__python__rooted "$3" "$__testing__frameworks__python__file_entry__get_8")"
  @get __testing__frameworks__python__file_entry__get_9 "$2" '.value.summary.covered_lines' 0
  @get __testing__frameworks__python__file_entry__get_10 "$2" '.value.summary.num_statements' 0
  __testing__frameworks__python__file_entry__entry="$(coverage__file_entry \
    "$__testing__frameworks__python__file_entry__get_9" \
    "$__testing__frameworks__python__file_entry__get_10" \
    "$4" \
    "$5"
  )"
  @set __testing__frameworks__python__file_entry__out "$1" ".\"$__testing__frameworks__python__file_entry__path\"" "$__testing__frameworks__python__file_entry__entry"
  println "$__testing__frameworks__python__file_entry__out"
}

:<<'FUN'
Prints coverage.py's JSON report as the report shape lib/coverage/api.sh
gates on: coverage.py counts statements, so the metric is lines; each file is
keyed by its workspace-relative path and attributed to the suite.

args:
  $1  coverage.py's report, as it wrote it
  $2  The suite's project dir
  $3  The suite's name
  $4  The runner's id, unittest or pytest
FUN
__testing__frameworks__python__normalized() {
  @obj __testing__frameworks__python__normalized__obj_11
  @get __testing__frameworks__python__normalized__get_12 "$1" '.files' "$__testing__frameworks__python__normalized__obj_11"
  @entries __testing__frameworks__python__normalized__entries_13 "$__testing__frameworks__python__normalized__get_12"
  @obj __testing__frameworks__python__normalized__obj_14
  @reduce __testing__frameworks__python__normalized__files __testing__frameworks__python__file_entry \
    "$__testing__frameworks__python__normalized__entries_13" \
    "$__testing__frameworks__python__normalized__obj_14" \
    "$2" \
    "$3" \
    "$4"
  @get __testing__frameworks__python__normalized__get_15 "$1" '.totals.covered_lines' 0
  @get __testing__frameworks__python__normalized__get_16 "$1" '.totals.num_statements' 0
  coverage__report lines \
    "$__testing__frameworks__python__normalized__files" \
    "$__testing__frameworks__python__normalized__get_15" \
    "$__testing__frameworks__python__normalized__get_16"
}

:<<'PUB_FUN'
Runs the framework module <module> in the suite's project dir with the
arguments given, under coverage.py when the suite names sources, and then
writes the JSON report coverage_summary reads. Passes the framework's exit
code through; the report is written whether or not the tests passed, since a
failing run is one a reader wants the numbers of.

args:
  $1  The effective suite config
  $2  The module `python -m` runs: unittest or pytest
  $@  The arguments to the module
PUB_FUN
testing__frameworks__python__run() {
  __testing__frameworks__python__run__cfg="$1"
  __testing__frameworks__python__run__framework="$2"
  shift 2
  __testing__frameworks__python__run__dir="$(__testing__frameworks__python__project_dir "$__testing__frameworks__python__run__cfg")"
  __testing__frameworks__python__run__interpreter="$(__testing__frameworks__python__interpreter "$__testing__frameworks__python__run__cfg")"
  __testing__frameworks__python__run__sources="$(__testing__frameworks__python__sources "$__testing__frameworks__python__run__cfg")"
  if ! @defined "$__testing__frameworks__python__run__sources"; then
    (
      cd "$PROJ/$__testing__frameworks__python__run__dir" || exit
      # shellcheck disable=SC2086  # the interpreter is one or several words on purpose
      $__testing__frameworks__python__run__interpreter -m "$__testing__frameworks__python__run__framework" "$@"
    )
    return
  fi

  __testing__frameworks__python__run__report="$(__testing__frameworks__python__report_path "$__testing__frameworks__python__run__cfg")"
  mkdir -p "$(dirname "$__testing__frameworks__python__run__report")"
  (
    cd "$PROJ/$__testing__frameworks__python__run__dir" || exit
    # shellcheck disable=SC2086  # the interpreter is one or several words on purpose
    $__testing__frameworks__python__run__interpreter -m coverage run \
      --source="$__testing__frameworks__python__run__sources" \
      -m "$__testing__frameworks__python__run__framework" "$@"
    __testing__frameworks__python__run__status=$?
    # shellcheck disable=SC2086
    $__testing__frameworks__python__run__interpreter -m coverage json -q -o "$__testing__frameworks__python__run__report" || exit
    exit "$__testing__frameworks__python__run__status"
  )
}

:<<'PUB_FUN'
Prints the last run's coverage report, normalized to the shape lib/coverage/api.sh
works on (metric "lines"), with every file attributed to the suite the config
names, defaulting to the runner's id. Fails when no report exists yet, or when
the suite names no sources and so measured nothing. The coverage_summary role
of both runners.

args:
  $1  The effective suite config
PUB_FUN
testing__frameworks__python__summary() {
  __testing__frameworks__python__summary__report="$(__testing__frameworks__python__report_path "$1")"
  if [ ! -f "$__testing__frameworks__python__summary__report" ]; then
    @get __testing__frameworks__python__summary__get_17 "$1" '.runner' python
    error "$__testing__frameworks__python__summary__get_17: no coverage report at $__testing__frameworks__python__summary__report; run a suite that names its source first"
    return 1
  fi

  @get __testing__frameworks__python__summary__get_18 "$1" '.runner' python
  @get __testing__frameworks__python__summary__get_19 "$1" '.suite' "$__testing__frameworks__python__summary__get_18"
  @get __testing__frameworks__python__summary__get_20 "$1" '.runner' python
  __testing__frameworks__python__normalized \
    "$(cat "$__testing__frameworks__python__summary__report")" \
    "$(__testing__frameworks__python__project_dir "$1")" \
    "$__testing__frameworks__python__summary__get_19" \
    "$__testing__frameworks__python__summary__get_20"
}
