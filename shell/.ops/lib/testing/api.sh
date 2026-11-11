#!/usr/bin/env bash

:<<'MODULE'
Test Impact Analysis (TIA) facade -- the single entry point for the testing
module. TIA selects which tests to run for a change by mapping changed files to
areas, areas to test files, and test files to a framework runner.

Three layers, only the last of which may know a framework:

  resolver.sh   pure file/path/area logic
  adapter.sh    framework registry + contract
  frameworks/   concrete adapters, one per framework

A consumer loads every runner by importing frameworks.sh, which finds each
plugin by its filename, or imports the one plugin its project runs and loads
it by id:

  import "$SHELLOPS_DIR/lib/testing/api.sh"
  import "$SHELLOPS_DIR/lib/testing/frameworks.sh"

  import "$SHELLOPS_DIR/lib/testing/frameworks/nextest/nextest.runner.op.sh"
  testing__load_runner nextest
MODULE

import \
  "$SHELLOPS_DIR/lib/testing/resolver.sh" \
  "$SHELLOPS_DIR/lib/testing/adapter.sh"
