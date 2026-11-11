#!/bin/sh

import "$SHELLOPS_DIR/lib/testing/scorecard/api.sh"

:<<'MODULE'
The scorecard as the short markdown a comment carries.

The terminal report is a wall of rows for whoever asked for it; a comment is
read by someone who did not ask, so the summary says only what would change a
decision: whether the mapping is complete, how narrow selection is running, and
what it is buying. Everything else stays in the report the summary points at.

  testing__scorecard__summary           the scorecard as markdown
  testing__scorecard__findings          the findings behind its counts, as list lines
  testing__scorecard__findings_section  the first of those lines under a heading
                                        that gives their number, and how
                                        many are left out, or nothing

Usage:
  import "$SHELLOPS_DIR/lib/testing/scorecard/summary.sh"

  testing__scorecard__summary "$(testing__scorecard__scorecard)"
MODULE

__testing__scorecard__summary__FINDINGS="$SHELLOPS_DIR/lib/testing/scorecard/findings.awk"

# CONST: The most findings the findings section lists.
__testing__scorecard__summary__FINDINGS_LISTED=10

:<<'PUB_FUN'
Renders a scorecard struct as markdown on stdout.

args:
  $1  The scorecard (from testing__scorecard__scorecard)

Usage: testing__scorecard__summary "$scorecard"

Example, this repo over a month of recorded runs:

  ## Test selection

  **Mapping:** 67 areas, complete

  - unmapped files: 0
  - missing area paths: 0
  - dead test entries: 0
  - orphan tests: 0
  - untested areas: 0
  - undeclared directories (advisory): 0
  - trace gaps (advisory): 3
  - suites reaching out of tree unmarked (advisory): 0

  **Rollout:** 24 runs (19 selected, 5 full suite)

  - selection ratio: 7.3%
  - time saved: 105m
  - flaky tests (passed on retry): 0
  - most common selection reason: impacted_areas (19 runs)
  - confidence: 16 of 20 narrowed & inert runs in a row without missed failures since the escape at 2026-09-05T22:16:00Z
  - narrowed & inert runs without a verdict: 0

The trace-gaps and reaching-suites lines appear once a traced full run has
left a map: files a test was seen reading that a change to would not select
it, and suites whose tests were seen reaching an address or a program the
trace cannot follow without the config saying so. The reason
line says which branch of the dispatch decision dominated:
"impacted_areas (19 runs)" reads as selection mostly narrowing, while
"no_labels (19 runs)" would read as most MRs never getting labeled -- wide
runs whose fix is labeling, not the resolver. The confidence line is the
phase gate read off the block: the narrowed and inert runs judged clean since
the last would-be escape, against the count the gate asks for.
PUB_FUN
testing__scorecard__summary() {
  @let "$1" __testing__scorecard__summary__ configured summary rollout
  @defined "$__testing__scorecard__summary__configured" \
    || __testing__scorecard__summary__configured=false
    @defined "$__testing__scorecard__summary__rollout" \
    || @obj __testing__scorecard__summary__rollout

  if ! @is_true "$__testing__scorecard__summary__configured"; then
    println "## Test selection"
    printf '\n%s\n' "No testing config in this repo, so there is nothing to score."
    return 0
  fi

  println "## Test selection"
  printf '\n'
  __testing__scorecard__summary__mapping "$__testing__scorecard__summary__summary"
  printf '\n'
  __testing__scorecard__summary__rollout "$__testing__scorecard__summary__rollout"
  @unlet __testing__scorecard__summary__ configured summary rollout
}

:<<'FUN'
The mapping-health section: the verdict, then the gap counts behind it.

args:
  $1  The summary block
FUN
__testing__scorecard__summary__mapping() {
  @let "$1" __testing__scorecard__summary__mapping__ areas ready unmapped_files missing_paths dead_tests orphan_tests untested_areas undeclared_dirs trace_gaps reach_gaps
  @defined "$__testing__scorecard__summary__mapping__ready" \
    || __testing__scorecard__summary__mapping__ready=false
  @defined "$__testing__scorecard__summary__mapping__untested_areas" \
    || __testing__scorecard__summary__mapping__untested_areas=0
  @defined "$__testing__scorecard__summary__mapping__undeclared_dirs" \
    || __testing__scorecard__summary__mapping__undeclared_dirs=0

  printf '**Mapping:** %s areas, %s\n\n' \
    "$__testing__scorecard__summary__mapping__areas" \
    "$(__testing__scorecard__summary__verdict "$__testing__scorecard__summary__mapping__ready")"
  printf -- '- unmapped files: %s\n' "$__testing__scorecard__summary__mapping__unmapped_files"
  printf -- '- missing area paths: %s\n' "$__testing__scorecard__summary__mapping__missing_paths"
  printf -- '- dead test entries: %s\n' "$__testing__scorecard__summary__mapping__dead_tests"
  printf -- '- orphan tests: %s\n' "$__testing__scorecard__summary__mapping__orphan_tests"
  printf -- '- untested areas: %s\n' "$__testing__scorecard__summary__mapping__untested_areas"
  printf -- '- undeclared directories (advisory): %s\n' "$__testing__scorecard__summary__mapping__undeclared_dirs"
  if @defined "$__testing__scorecard__summary__mapping__trace_gaps"; then
    printf -- '- trace gaps (advisory): %s\n' "$__testing__scorecard__summary__mapping__trace_gaps"
  fi
  if @defined "$__testing__scorecard__summary__mapping__reach_gaps"; then
    printf -- '- suites reaching out of tree unmarked (advisory): %s\n' "$__testing__scorecard__summary__mapping__reach_gaps"
  fi
  @unlet __testing__scorecard__summary__mapping__ areas ready unmapped_files missing_paths dead_tests orphan_tests untested_areas undeclared_dirs trace_gaps reach_gaps
}

:<<'FUN'
The mapping verdict in words.

args:
  $1  The ready flag
FUN
__testing__scorecard__summary__verdict() {
  if @is_true "$1"; then
    printf 'complete\n'
    return 0
  fi
  printf 'incomplete\n'
}

:<<'FUN'
The rollout section: what the recorded runs say selection is doing, or that
nothing has recorded a run yet.

args:
  $1  The rollout block ({} when absent)
FUN
__testing__scorecard__summary__rollout() {
  if @len __testing__scorecard__summary__rollout__len_1 "$1"; [ "$__testing__scorecard__summary__rollout__len_1" -eq 0 ]; then
    printf '**Rollout:** no runs recorded yet.\n'
    return 0
  fi

  @let "$1" __testing__scorecard__summary__rollout__ runs selected_runs full_suite_runs selected_tests selectable_tests seconds_saved flaky_tests clean_streak last_escape_at clean_streak_goal unverdicted_runs
  @defined "$__testing__scorecard__summary__rollout__flaky_tests" \
    || __testing__scorecard__summary__rollout__flaky_tests=0
  @defined "$__testing__scorecard__summary__rollout__clean_streak" \
    || __testing__scorecard__summary__rollout__clean_streak=0
  @defined "$__testing__scorecard__summary__rollout__clean_streak_goal" \
    || __testing__scorecard__summary__rollout__clean_streak_goal="$__testing__scorecard__CLEAN_STREAK_GOAL"
  @defined "$__testing__scorecard__summary__rollout__unverdicted_runs" \
    || __testing__scorecard__summary__rollout__unverdicted_runs=0

  printf '**Rollout:** %s runs (%s selected, %s full suite)\n\n' \
    "$__testing__scorecard__summary__rollout__runs" \
    "$__testing__scorecard__summary__rollout__selected_runs" \
    "$__testing__scorecard__summary__rollout__full_suite_runs"
  printf -- '- selection ratio: %s\n' "$(testing__metrics__ratio_display \
    "$__testing__scorecard__summary__rollout__selected_tests" \
    "$__testing__scorecard__summary__rollout__selectable_tests"
  )"
  printf -- '- time saved: %s\n' "$(testing__metrics__minutes_display \
    "$__testing__scorecard__summary__rollout__seconds_saved"
  )"
  printf -- '- flaky tests (passed on retry): %s\n' "$__testing__scorecard__summary__rollout__flaky_tests"
  @get __testing__scorecard__summary__rollout__get_2 "$1" '.top_reason.reason'
  @get __testing__scorecard__summary__rollout__get_3 "$1" '.top_reason.runs'
  printf -- '- most common selection reason: %s (%s runs)\n' \
    "$__testing__scorecard__summary__rollout__get_2" \
    "$__testing__scorecard__summary__rollout__get_3"
  printf -- '- confidence: %s\n' "$(testing__metrics__streak_display \
    "$__testing__scorecard__summary__rollout__clean_streak" \
    "$__testing__scorecard__summary__rollout__last_escape_at" \
    "$__testing__scorecard__summary__rollout__clean_streak_goal"
  )"
  printf -- '- narrowed & inert runs without a verdict: %s\n' "$__testing__scorecard__summary__rollout__unverdicted_runs"
  @unlet __testing__scorecard__summary__rollout__ runs selected_runs full_suite_runs selected_tests selectable_tests seconds_saved flaky_tests clean_streak last_escape_at clean_streak_goal unverdicted_runs
}

:<<'PUB_FUN'
The findings behind a scorecard's gap counts as markdown list lines, one per
finding grouped by category; nothing when the mapping is clean. The summary
says only counts, which is right for a comment nobody asked for; a red or
yellow verdict is the one case where the lines change a decision, so the
comment it leaves carries these under the summary.

  testing__scorecard__findings "$scorecard"
  -> - unmapped files: `stray.sh` (1)
     - orphan tests (`unit`): `spec/lexer_spec.sh`

args:
  $1  The scorecard (from testing__scorecard__scorecard)
PUB_FUN
testing__scorecard__findings() {
  @run_awk __testing__scorecard__findings__out "$__testing__scorecard__summary__FINDINGS" "$1" \
    --load "$__testing__scorecard__RULES" || return 1
  println "$__testing__scorecard__findings__out"
}

: <<'PUB_FUN'
Prints the findings section of a comment, preceded by a blank line: a
heading that gives the number of findings, the first 10 findings, and a
last line that says how many are left out. Prints nothing when there are no
findings, so a caller appends the section to the summary without checking
first. The scorecard's JSON report lists every finding.

  testing__scorecard__findings_section "$scorecard"
  ->
     **Findings:** 680

     - trace gap (advisory): `.envrc` falls to `repo.envrc`; 16 test(s) ...
     (nine more findings)
     - and 670 others...

args:
  $1  The scorecard (from testing__scorecard__scorecard)
PUB_FUN
testing__scorecard__findings_section() {
  __testing__scorecard__findings_section__lines="$(testing__scorecard__findings "$1")" || return 1
  @defined "$__testing__scorecard__findings_section__lines" || return 0

  __testing__scorecard__findings_section__total="$(println "$__testing__scorecard__findings_section__lines" \
    | grep -c ''
  )"
  printf '\n**Findings:** %s\n\n' "$__testing__scorecard__findings_section__total"
  println "$__testing__scorecard__findings_section__lines" \
    | head -n "$__testing__scorecard__summary__FINDINGS_LISTED"
  __testing__scorecard__findings_left_out "$__testing__scorecard__findings_section__total"
}

: <<'FUN'
Prints the last line of the findings section, which says how many findings
the section leaves out. Prints nothing when the section lists them all.

  __testing__scorecard__findings_left_out 680  ->  - and 670 others...
  __testing__scorecard__findings_left_out 11   ->  - and 1 other...
  __testing__scorecard__findings_left_out 10   ->  (nothing)

args:
  $1  The number of findings
FUN
__testing__scorecard__findings_left_out() {
  __testing__scorecard__findings_left_out__count=$(($1 - __testing__scorecard__summary__FINDINGS_LISTED))
  if [ "$__testing__scorecard__findings_left_out__count" -le 0 ]; then
    return 0
  fi
  if [ "$__testing__scorecard__findings_left_out__count" -eq 1 ]; then
    printf -- '- and 1 other...\n'
  else
    printf -- '- and %s others...\n' "$__testing__scorecard__findings_left_out__count"
  fi
}
