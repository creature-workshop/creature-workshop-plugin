#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'FRAGMENT'
Where a cargo-llvm-cov run of a suite leaves its export, for the run that
writes it and the coverage_summary that reads it.
FRAGMENT

:<<'FUN'
The absolute path cargo-llvm-cov writes its JSON export to: llvm-cov.json inside
the suite's report_dir, joined under $PROJ. A top-level helper shared by the run
roles and coverage_summary, so the writer and the reader agree on the location.

args:
  $1  The effective suite config
FUN
__testing__frameworks__llvm_cov__report_path() {
  @get __testing__frameworks__llvm_cov__report_path__get_1 "$1" '.report_dir' 'target/coverage/llvm-cov'
  printf '%s/%s/llvm-cov.json' "$PROJ" "$__testing__frameworks__llvm_cov__report_path__get_1"
}
