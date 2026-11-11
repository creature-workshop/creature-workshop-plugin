#!/bin/sh

import "$SHELLOPS_DIR/lib/testing/scorecard/api.sh"

:<<'MODULE'
The scorecard's verdict, and the exit status a CI job carries it as.

  testing__scorecard__verdict      clean, blocked or advisory, for a report
  testing__scorecard__exit_status  the status a job exits with for a verdict
MODULE

__testing__scorecard__gate__CLEAN="clean"
__testing__scorecard__gate__BLOCKED="blocked"
__testing__scorecard__gate__ADVISORY="advisory"

:<<'PUB_FUN'
Logs and prints the verdict for a report: clean when the mapping is complete
or the repo has no testing config, blocked when the mapping is incomplete,
advisory when it is complete but carries findings that cost time and not
safety (undeclared directories), or that the trace map names and the
mapping has not yet answered for (trace gaps, reach gaps). A report missing the blocks the verdict is
counted from is blocked: a check that never answered leaves zero gaps behind,
and passing on that is a gate reporting perfect health it did not measure.

  testing__scorecard__verdict "$report"  ->  advisory

  $1  The scorecard report (from testing__scorecard__scorecard)
PUB_FUN
testing__scorecard__verdict() {
  if ! @is_true "$(testing__scorecard__is_well_formed "$1")"; then
    log "testing scorecard: the report is malformed -- a check produced no answer."
    println "$__testing__scorecard__gate__BLOCKED"
    return 0
  fi

  if @get __testing__scorecard__verdict__get_1 "$1" '.configured'; ! @is_true "$__testing__scorecard__verdict__get_1"; then
    println "$__testing__scorecard__gate__CLEAN"
    return 0
  fi

  if @get __testing__scorecard__verdict__get_2 "$1" '.summary.ready'; ! @is_true "$__testing__scorecard__verdict__get_2"; then
    log "testing scorecard: mapping incomplete -- see gaps above."
    println "$__testing__scorecard__gate__BLOCKED"
    return 0
  fi

  @get __testing__scorecard__verdict__advisory "$1" '.summary.undeclared_dirs' 0
  if [ "$__testing__scorecard__verdict__advisory" -gt 0 ]; then
    log "testing scorecard: mapping complete, with $__testing__scorecard__verdict__advisory undeclared directory(ies) reported above -- advisory."
    println "$__testing__scorecard__gate__ADVISORY"
    return 0
  fi

  @get __testing__scorecard__verdict__trace "$1" '.summary.trace_gaps' 0
  if [ "$__testing__scorecard__verdict__trace" -gt 0 ]; then
    log "testing scorecard: mapping complete, with $__testing__scorecard__verdict__trace file(s) the trace map reads that selection would not answer for, reported above -- advisory."
    println "$__testing__scorecard__gate__ADVISORY"
    return 0
  fi

  @get __testing__scorecard__verdict__reach "$1" '.summary.reach_gaps' 0
  if [ "$__testing__scorecard__verdict__reach" -gt 0 ]; then
    log "testing scorecard: mapping complete, with $__testing__scorecard__verdict__reach suite(s) seen reaching outside their process tree and not marked out_of_tree, reported above -- advisory."
    println "$__testing__scorecard__gate__ADVISORY"
    return 0
  fi

  println "$__testing__scorecard__gate__CLEAN"
}

:<<'PUB_FUN'
The exit status a CI job carries a verdict as: 0 for clean, 1 for blocked so
the job fails, 2 for advisory so a job mapping that code to allow_failure
shows passed with warnings. The one place a verdict becomes a number, at the
boundary where a job can carry nothing else.

  testing__scorecard__exit_status advisory  ->  2

  $1  The verdict
PUB_FUN
testing__scorecard__exit_status() {
  if [ "$1" = "$__testing__scorecard__gate__CLEAN" ]; then
    printf '0\n'
  elif [ "$1" = "$__testing__scorecard__gate__BLOCKED" ]; then
    printf '1\n'
  else
    printf '2\n'
  fi
}
