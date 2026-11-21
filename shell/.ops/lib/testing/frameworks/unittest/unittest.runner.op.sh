#!/usr/bin/env bash

: <<'MODULE'
unittest runner plugin for Test Impact Analysis (TIA): the standard library's
runner, by file, under coverage.py when the suite names the packages to
measure.
MODULE

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/adapter.sh" \
  "$SHELLOPS_DIR/lib/testing/frameworks/python/coverage.sh"

:<<'DOC'
The unittest framework runner; inner @-roles re-home to unittest_<role> on load.
DOC
@runner.unittest() {
  :<<'FUN'
Runs the given $PROJ-relative test files through unittest, which takes a file
path as the module to load. Zero files fail loudly, so a stale selection never
passes silently.
FUN
  @run_selected() {
    __unittest_run_selected__cfg="$1"
    shift
    if [ "$#" -eq 0 ]; then
      error "unittest_run_selected: no test files specified"
      return 1
    fi

    testing__frameworks__python__run "$__unittest_run_selected__cfg" unittest "$@"
  }

  :<<'FUN'
Runs the whole suite: unittest's discovery from the suite's root with the
project dir as the top level, matching the suite's glob.
FUN
  @run_all() {
    @get __at1 "$1" '.root' 'tests'
    @get __at2 "$1" '.glob' 'test_*.py'
    testing__frameworks__python__run "$1" unittest discover \
      -s "$__at1" \
      -t . \
      -p "$__at2"
  }

  :<<'FUN'
The manifest-facing JSON Schema fragment for a unittest suite.
FUN
  @suite_schema() {
    cat "$SHELLOPS_DIR/lib/testing/frameworks/unittest/suite.schema.json"
  }

  :<<'FUN'
The resolver-owned discovery strategies unittest opts into.
FUN
  @strategies() {
    @arr __at_out sibling filename
    println "$__at_out"
  }

  :<<'FUN'
unittest's default suite config: tests under tests/ named test_<stem>.py, run by
python3, measuring nothing until the suite names its sources.
FUN
  @suite_defaults() {
    @arr __at3
    @arr __at4 sibling filename
    @obj __at_out \
      '.runner' "unittest" \
      '.project_dir' "." \
      '.root' "tests" \
      '.glob' "test_*.py" \
      '.interpreter' "python3" \
      '.source' "$__at3" \
      '.report_dir' ".ops/cache/coverage/unittest" \
      '.discovery' "$__at4"
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
