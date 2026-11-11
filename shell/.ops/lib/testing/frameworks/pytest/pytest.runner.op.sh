#!/usr/bin/env bash

: <<'MODULE'
pytest runner plugin for Test Impact Analysis (TIA): pytest by file, under
coverage.py when the suite names the packages to measure. pytest runs
unittest suites unchanged, so a project moves to it without rewriting a test.
MODULE

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/adapter.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/python/coverage.sh"

:<<'DOC'
The pytest framework runner; inner @-roles re-home to pytest_<role> on load.
DOC
@runner.pytest() {
  :<<'FUN'
Runs the given $PROJ-relative test files through pytest, which takes a file
path as a test module. Zero files fail loudly, so a stale selection never
passes silently.
FUN
  @run_selected() {
    __pytest_run_selected__cfg="$1"
    shift
    if [ "$#" -eq 0 ]; then
      error "pytest_run_selected: no test files specified"
      return 1
    fi

    testing__frameworks__python__run "$__pytest_run_selected__cfg" pytest "$@"
  }

  :<<'FUN'
Runs the whole suite: pytest over the suite's root, collecting by its own
rules; the suite's glob names the files TIA maps, which pytest's own patterns
should agree with.
FUN
  @run_all() {
    @get __at1 "$1" '.root' 'tests'
    testing__frameworks__python__run "$1" pytest "$__at1"
  }

  :<<'FUN'
The manifest-facing JSON Schema fragment for a pytest suite.
FUN
  @suite_schema() {
    cat "$SHELLOPS_DIR/lib/testing/frameworks/pytest/suite.schema.json"
  }

  :<<'FUN'
The resolver-owned discovery strategies pytest opts into.
FUN
  @strategies() {
    @arr __at_out sibling filename
    println "$__at_out"
  }

  :<<'FUN'
pytest's default suite config: tests under tests/ named test_<stem>.py, run by
python3, measuring nothing until the suite names its sources.
FUN
  @suite_defaults() {
    @arr __at2
    @arr __at3 sibling filename
    @obj __at_out \
      '.runner' "pytest" \
      '.project_dir' "." \
      '.root' "tests" \
      '.glob' "test_*.py" \
      '.interpreter' "python3" \
      '.source' "$__at2" \
      '.report_dir' ".ops/cache/coverage/pytest" \
      '.discovery' "$__at3"
    println "$__at_out"
  }

  :<<'FUN'
The last run's coverage report, as lib/testing/frameworks/python/coverage.sh
normalizes it: metric lines, every file attributed to the suite.
FUN
  @coverage_summary() {
    testing__frameworks__python__summary "$1"
  }
}
