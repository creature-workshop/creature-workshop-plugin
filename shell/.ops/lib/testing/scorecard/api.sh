#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/testing/resolver.sh" \
  "$SHELLOPS_DIR/lib/testing/adapter.sh" \
  "$SHELLOPS_DIR/lib/testing/metrics/api.sh" \
  "$SHELLOPS_DIR/lib/testing/trace/location.sh" \
  "$SHELLOPS_DIR/lib/testing/trace/audit.sh" \
  "$SHELLOPS_DIR/lib/areas/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh"

:<<'MODULE'
Readiness reporting for impact-based test selection.

Selection is only as safe as the area mapping is complete, and nothing else
measures that completeness. This module computes the report the rollout's
promotion gates read (planning/docs/test-selection.md), entirely read-only
from the manifest and tree:

  unmapped       tracked source files (outside the test trees) no area covers
  missing_paths  area paths that no longer exist on disk
  dead_tests     explicit test entries matching nothing on disk
  orphans        test files under a suite root that no area would ever select
  untested_areas code areas with no test attached and no inert declaration
  undeclared_dirs directories under a grouping area that no child area claims
  trace_gaps     files a test was traced reading that a change to would not
                 select it, when a trace map has been recorded
  reach_gaps     suites a test was traced reaching outside its process tree
                 from, an address or a program the trace cannot follow, that
                 the config does not mark out_of_tree

plus per-area rows (paths, per-suite test counts, how many of those the
importers of the area brought, flags) and a summary whose .ready flag is the
phase-1 entry criterion: every tracked path mapped, no dead references, no
orphans, no untested area. undeclared_dirs is advisory and stays out of
that verdict: an undeclared directory's files fall to the grouping area and
run whatever it runs, so the gap costs time, never safety. trace_gaps and
reach_gaps are advisory too, and present only once a traced full run has
left a map (lib/testing/trace).

Mapping health answers "is selection safe to switch on?". The rollout block
answers "was it worth switching on?", summed from the per-run metrics records
(lib/testing/metrics/api.sh). No records, no block: leaving it out entirely
keeps "never measured" from reading as "measured zero".

Consumers (testing__scorecard__scorecard is the struct, testing__scorecard__render the
human view):

  CI gate         a job runs `ops test scorecard --json`, then gates on
                  `.summary.ready` (or specific gap counts) to block a merge
                  while the mapping is incomplete.
  Drift watch     a scheduled job diffs `.gaps` and opens an issue when a
                  previously-clean repo grows unmapped paths or orphan tests.
  Local pre-flight a maintainer runs `ops test scorecard` before opening an
                  MR that adds an area, to confirm no orphans or dead entries.
  README render   `--json` feeds the badge / SVG card renderer (OPS-266); the
                  coverage rows below are what make that worth rendering.
MODULE

__testing__scorecard__UNMAPPED="$SHELLOPS_DIR/lib/testing/scorecard/unmapped_files.awk"
__testing__scorecard__AREA_PATHS="$SHELLOPS_DIR/lib/testing/scorecard/area_paths.awk"
__testing__scorecard__DEAD_TESTS="$SHELLOPS_DIR/lib/testing/scorecard/dead_tests.awk"
__testing__scorecard__ORPHANS="$SHELLOPS_DIR/lib/testing/scorecard/orphans.awk"
__testing__scorecard__AREA_ROWS="$SHELLOPS_DIR/lib/testing/scorecard/area_rows.awk"
__testing__scorecard__UNTESTED_AREAS="$SHELLOPS_DIR/lib/testing/scorecard/untested_areas.awk"
__testing__scorecard__UNDECLARED_DIRS="$SHELLOPS_DIR/lib/testing/scorecard/undeclared_dirs.awk"
__testing__scorecard__RENDER="$SHELLOPS_DIR/lib/testing/scorecard/render.awk"

:<<'CONST'
The gate into phase 2 (planning/docs/test-selection.md, Rollout phases): how
many narrowed and inert runs in a row without missed failures since the last
would-be escape the phase-1 shadow must show before selection gates merge
requests. The count a report is judged against when its entrypoint names
none.
CONST
__testing__scorecard__CLEAN_STREAK_GOAL=20

# CONST: The field separator area_paths.awk prints, for the missing-path read loop.
__testing__scorecard__TAB="$(printf '\t')"

: <<'CONST'
The rules that the testing awk programs share, loaded ahead of every
scorecard program: the area-coverage and glob rules that the resolver
selects by.
CONST
__testing__scorecard__RULES="$SHELLOPS_DIR/lib/testing/testing.awk"

:<<'FUN'
A full scorecard report.

args:
  $1  The per-area rows (array of rows)
  $2  The gaps block
  $3  The summary block
FUN
__testing__scorecard__report() {
  @true __testing__scorecard__report__true_1
  @obj __testing__scorecard__report__out \
    '.configured' "$__testing__scorecard__report__true_1" \
    '.areas' "$1" \
    '.gaps' "$2" \
    '.summary' "$3"
  println "$__testing__scorecard__report__out"
}

:<<'FUN'
The report for a repo with no testing config -- nothing to score.
FUN
__testing__scorecard__unconfigured_report() {
  @false __testing__scorecard__unconfigured_report__false_2
  @obj __testing__scorecard__unconfigured_report__out '.configured' "$__testing__scorecard__unconfigured_report__false_2"
  println "$__testing__scorecard__unconfigured_report__out"
}

:<<'FUN'
The gaps block of a report.

args:
  $1  The unmapped block ({files, top_level})
  $2  The missing-path findings (array)
  $3  The dead-test findings (array)
  $4  The orphans block ({"<suite>": [<file>, ...]})
  $5  The untested areas (array of names)
  $6  The undeclared directories (array of {area, path})
FUN
__testing__scorecard__gaps() {
  @obj __testing__scorecard__gaps__out \
    '.unmapped' "$1" \
    '.missing_paths' "$2" \
    '.dead_tests' "$3" \
    '.orphans' "$4" \
    '.untested_areas' "$5" \
    '.undeclared_dirs' "$6"
  println "$__testing__scorecard__gaps__out"
}

:<<'FUN'
One missing-area-path finding.

args:
  $1  The area name
  $2  The path that no longer exists on disk
FUN
__testing__scorecard__missing_path_finding() {
  @obj __testing__scorecard__missing_path_finding__out \
    '.area' "$1" \
    '.path' "$2"
  println "$__testing__scorecard__missing_path_finding__out"
}

:<<'FUN'
The summary block of a report: the area count, the gap counts, and the
ready verdict.

args:
  $1  The area count
  $2  The gap counts ({unmapped_files, missing_paths, dead_tests,
      orphan_tests, untested_areas, undeclared_dirs})
  $3  The ready verdict (true/false)
FUN
__testing__scorecard__summary_block() {
  @set __testing__scorecard__summary_block__with_areas "$2" '.areas' "$1" || return 1
  @set __testing__scorecard__summary_block__out "$__testing__scorecard__summary_block__with_areas" '.ready' "$3"
  println "$__testing__scorecard__summary_block__out"
}

:<<'PUB_FUN'
Builds the full scorecard for $PROJ as a JSON struct (see the constructors
above for the shape). A repo with no `testing` block yields
{"configured": false}. Returns 1 when the manifest's testing.suites config
fails schema validation, and when any check could not answer.

Every step is bound to a name and its status checked before the next reads it.
A check that fell over answered nothing, and an absent answer counted as zero
gaps would report a perfect mapping nobody measured.

args:
  $1  Options ({clean_streak_goal}), each optional; absent, the report is
      judged against the module's defaults

Usage: testing__scorecard__scorecard
       testing__scorecard__scorecard "$(@obj '.clean_streak_goal' 10)"
PUB_FUN
testing__scorecard__scorecard() {
  __testing__scorecard__TESTING_SCORECARD_SCORECARD_OPTIONS="${1:-}"
  @defined "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_OPTIONS" || @obj __testing__scorecard__TESTING_SCORECARD_SCORECARD_OPTIONS
  @get __testing__scorecard__TESTING_SCORECARD_SCORECARD_GOAL "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_OPTIONS" '.clean_streak_goal' "$__testing__scorecard__CLEAN_STREAK_GOAL"

  __testing__scorecard__TESTING_SCORECARD_SCORECARD_CONFIG="$(areas__load_areas_config)"
  if ! @defined "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_CONFIG"; then
    __testing__scorecard__unconfigured_report
    return 0
  fi

  @obj __testing__scorecard__scorecard__obj_3
  @get __testing__scorecard__TESTING_SCORECARD_SCORECARD_SUITES_CFG "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_CONFIG" '.suites' "$__testing__scorecard__scorecard__obj_3" || return 1
  if ! testing__validate_suites "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_SUITES_CFG"; then
    error "testing/scorecard: invalid testing.suites config (see schema errors above)."
    return 1
  fi
  __testing__scorecard__TESTING_SCORECARD_SCORECARD_SUITES="$(testing__effective_suites "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_SUITES_CFG")" || return 1

  __testing__scorecard__TESTING_SCORECARD_SCORECARD_AREAS="$(areas__compute_areas "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_CONFIG")" || return 1
  __testing__scorecard__TESTING_SCORECARD_SCORECARD_ATTACHED="$(testing__attach_tests \
    "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_AREAS" \
    "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_SUITES"
  )" || return 1

  # One snapshot of the tracked tree, so every gap check reads the same set.
  __testing__scorecard__TESTING_SCORECARD_SCORECARD_FILES="$(__testing__scorecard__tracked_files)" || return 1
  __testing__scorecard__TESTING_SCORECARD_SCORECARD_GAPS_BLOCK="$(__testing__scorecard__gap_checks \
    "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_AREAS" \
    "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_ATTACHED" \
    "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_SUITES" \
    "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_FILES"
  )" || return 1
  __testing__scorecard__TESTING_SCORECARD_SCORECARD_ROWS="$(__testing__scorecard__area_rows "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_ATTACHED")" || return 1
  __testing__scorecard__TESTING_SCORECARD_SCORECARD_SUMMARY_VALUE="$(__testing__scorecard__summary \
    "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_ROWS" \
    "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_GAPS_BLOCK"
  )" || return 1
  __testing__scorecard__BUILT="$(__testing__scorecard__report \
    "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_ROWS" \
    "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_GAPS_BLOCK" \
    "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_SUMMARY_VALUE"
  )" || return 1

  __testing__scorecard__with_trace_gaps "$__testing__scorecard__BUILT" "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_ATTACHED" "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_SUITES" || return 1
  __testing__scorecard__with_rollout "$__testing__scorecard__BUILT" "$__testing__scorecard__TESTING_SCORECARD_SCORECARD_GOAL"
}

:<<'FUN'
Sets __testing__scorecard__BUILT to the report with the trace map's findings on it:
the audit's, as .gaps.trace_gaps and their count in .summary.trace_gaps,
and the suites seen reaching outside their tree unmarked, as
.gaps.reach_gaps and their count in .summary.reach_gaps, when a trace map
has been recorded; leaves it unchanged when none has, so a report that
never audited does not read as one that found nothing.

args:
  $1  The report
  $2  The attached areas
  $3  The effective suites
FUN
__testing__scorecard__with_trace_gaps() {
  __testing__scorecard__with_trace_gaps__map="$(testing__trace__latest_map)" || return 1
  if ! @defined "$__testing__scorecard__with_trace_gaps__map"; then
    __testing__scorecard__BUILT="$1"
    return 0
  fi

  __testing__scorecard__with_trace_gaps__findings="$(testing__trace__audit \
    "$__testing__scorecard__with_trace_gaps__map" \
    "$2"
  )" || return 1
  __testing__scorecard__with_trace_gaps__reach="$(testing__trace__reach \
    "$__testing__scorecard__with_trace_gaps__map" \
    "$3"
  )" || return 1
  @len __testing__scorecard__with_trace_gaps__len_4 "$__testing__scorecard__with_trace_gaps__findings"
  @len __testing__scorecard__with_trace_gaps__len_5 "$__testing__scorecard__with_trace_gaps__reach"
  @set __testing__scorecard__BUILT "$1" \
    '.gaps.trace_gaps' "$__testing__scorecard__with_trace_gaps__findings" \
    '.summary.trace_gaps' "$__testing__scorecard__with_trace_gaps__len_4" \
    '.gaps.reach_gaps' "$__testing__scorecard__with_trace_gaps__reach" \
    '.summary.reach_gaps' "$__testing__scorecard__with_trace_gaps__len_5"
}

:<<'FUN'
Runs every gap check over one snapshot of the tree and returns the gaps block,
failing when any of them could not answer.

args:
  $1  The areas object (pre-attach)
  $2  The attached areas
  $3  The effective suites
  $4  The tracked files (struct array)
FUN
__testing__scorecard__gap_checks() {
  __testing__scorecard__gap_checks__unmapped="$(__testing__scorecard__unmapped "$1" "$3" "$4")" || return 1
  __testing__scorecard__gap_checks__missing="$(__testing__scorecard__missing_paths "$1")" || return 1
  __testing__scorecard__gap_checks__dead="$(__testing__scorecard__dead_tests "$1" "$4")" || return 1
  __testing__scorecard__gap_checks__orphans="$(__testing__scorecard__orphans "$2" "$3" "$4")" || return 1
  __testing__scorecard__gap_checks__untested="$(__testing__scorecard__untested_areas "$2")" || return 1
  __testing__scorecard__gap_checks__undeclared="$(__testing__scorecard__undeclared_dirs "$1" "$4")" || return 1

  __testing__scorecard__gaps \
    "$__testing__scorecard__gap_checks__unmapped" \
    "$__testing__scorecard__gap_checks__missing" \
    "$__testing__scorecard__gap_checks__dead" \
    "$__testing__scorecard__gap_checks__orphans" \
    "$__testing__scorecard__gap_checks__untested" \
    "$__testing__scorecard__gap_checks__undeclared"
}

:<<'FUN'
The areas that are code no test speaks for: no test attached, not declared
inert, not a full-suite area, not a virtual grouping. A gap like any other:
selection has nothing to run for such an area, and nothing to run proves
nothing.

args:
  $1  The attached areas
FUN
__testing__scorecard__untested_areas() {
  @run_awk __testing__scorecard__untested_areas__out "$__testing__scorecard__UNTESTED_AREAS" \
    "$(__testing__scorecard__area_rows "$1")" \
    --load "$__testing__scorecard__RULES" || return 1
  println "$__testing__scorecard__untested_areas__out"
}

:<<'FUN'
Directories directly under a grouping area's source that no area's source
claims, as an array of {area, path} findings. A grouping area is one with
declared children; a leaf's internal directories are not reported. Advisory:
the files fall to the grouper and run whatever it runs, so the summary counts
these and the ready verdict does not.

  undeclared_dirs  ->  [{"area": "lib", "path": "lib/log"}]

args:
  $1  The areas object
  $2  The tracked files (struct array)
FUN
__testing__scorecard__undeclared_dirs() {
  @run_awk __testing__scorecard__undeclared_dirs__out "$__testing__scorecard__UNDECLARED_DIRS" \
    "$1" \
    --with "$2" \
    --load "$__testing__scorecard__RULES" || return 1
  println "$__testing__scorecard__undeclared_dirs__out"
}

:<<'PUB_FUN'
Prints true when a report carries what a gate reads: an unconfigured report, or
a configured one whose areas, gaps and summary each hold their own type.

args:
  $1  The scorecard report

Usage: [ "$(testing__scorecard__is_well_formed "$report")" = true ] || exit 1
PUB_FUN
testing__scorecard__is_well_formed() {
  if ! @is_valid "$1"; then
    @false __testing__scorecard__is_well_formed__out
    println "$__testing__scorecard__is_well_formed__out"
    return 0
  fi

  if @false __testing__scorecard__is_well_formed__false_6; @get __testing__scorecard__is_well_formed__get_7 "$1" '.configured' "$__testing__scorecard__is_well_formed__false_6"; ! @is_true "$__testing__scorecard__is_well_formed__get_7"; then
    @true __testing__scorecard__is_well_formed__out
    println "$__testing__scorecard__is_well_formed__out"
    return 0
  fi

  __testing__scorecard__blocks_typed "$1"
}

:<<'FUN'
Prints true when a configured report's areas, gaps, summary and ready verdict
each hold the type the constructors above give them.

args:
  $1  The scorecard report
FUN
__testing__scorecard__blocks_typed() {
  if @typeof __testing__scorecard__blocks_typed__typeof_11 "$1" '.summary.ready'; @typeof __testing__scorecard__blocks_typed__typeof_10 "$1" '.summary'; @typeof __testing__scorecard__blocks_typed__typeof_9 "$1" '.gaps'; @typeof __testing__scorecard__blocks_typed__typeof_8 "$1" '.areas'; [ "$__testing__scorecard__blocks_typed__typeof_8" = array ] \
    && [ "$__testing__scorecard__blocks_typed__typeof_9" = object ] \
    && [ "$__testing__scorecard__blocks_typed__typeof_10" = object ] \
    && [ "$__testing__scorecard__blocks_typed__typeof_11" = boolean ]; then
    @true __testing__scorecard__blocks_typed__out
    println "$__testing__scorecard__blocks_typed__out"
  else
    @false __testing__scorecard__blocks_typed__out
    println "$__testing__scorecard__blocks_typed__out"
  fi
}

:<<'FUN'
The report with its rollout block, when any run has been recorded; the report
unchanged when none has. The block carries the clean streak goal it is read
against, so a consumer of the JSON sees the count beside the gate.

args:
  $1  The report
  $2  The clean streak goal
FUN
__testing__scorecard__with_rollout() {
  __testing__scorecard__with_rollout__records="$(testing__metrics__records)" || return 1
  if @len __testing__scorecard__with_rollout__len_12 "$__testing__scorecard__with_rollout__records"; [ "$__testing__scorecard__with_rollout__len_12" -eq 0 ]; then
    println "$1"
    return 0
  fi

  __testing__scorecard__with_rollout__rollup="$(testing__metrics__rollup \
    "$__testing__scorecard__with_rollout__records"
  )" || return 1
  @set __testing__scorecard__with_rollout__judged \
    "$__testing__scorecard__with_rollout__rollup" \
    '.clean_streak_goal' \
    "$2" || return 1

  @set __testing__scorecard__with_rollout__out "$1" '.rollout' "$__testing__scorecard__with_rollout__judged"
  println "$__testing__scorecard__with_rollout__out"
}

:<<'PUB_FUN'
Renders a scorecard struct as a human report on stdout. The report text is
one awk pass (render.awk); only the rollout's display figures are rendered
here first, through the same metrics display helpers every other consumer
shows them through.

args:
  $1  The scorecard (from testing__scorecard__scorecard)

Usage: testing__scorecard__render "$scorecard"
PUB_FUN
testing__scorecard__render() {
  @let "$1" __testing__scorecard__render__ configured rollout
  @defined "$__testing__scorecard__render__configured" \
    || @false __testing__scorecard__render__configured
    @defined "$__testing__scorecard__render__rollout" \
    || @obj __testing__scorecard__render__rollout

  if ! @is_true "$__testing__scorecard__render__configured"; then
    log "testing scorecard: no testing config in manifest.json -- nothing to score."
    return 0
  fi

  __testing__scorecard__render__ratio=""
  __testing__scorecard__render__saved=""
  __testing__scorecard__render__streak=""
  if @len __testing__scorecard__render__len_13 "$__testing__scorecard__render__rollout"; [ "$__testing__scorecard__render__len_13" -gt 0 ]; then
    @let "$__testing__scorecard__render__rollout" __testing__scorecard__render__ selected_tests selectable_tests seconds_saved clean_streak last_escape_at clean_streak_goal
    __testing__scorecard__render__ratio="$(testing__metrics__ratio_display \
      "$__testing__scorecard__render__selected_tests" \
      "$__testing__scorecard__render__selectable_tests"
    )" || return 1
    __testing__scorecard__render__saved="$(testing__metrics__minutes_display \
      "$__testing__scorecard__render__seconds_saved"
    )" || return 1
    __testing__scorecard__render__streak="$(testing__metrics__streak_display \
      "$__testing__scorecard__render__clean_streak" \
      "$__testing__scorecard__render__last_escape_at" \
      "$__testing__scorecard__render__clean_streak_goal"
    )" || return 1
  fi

  @run_awk __testing__scorecard__render__text "$__testing__scorecard__RENDER" "$1" \
    --arg ratio "$__testing__scorecard__render__ratio" \
    --arg saved "$__testing__scorecard__render__saved" \
    --arg streak "$__testing__scorecard__render__streak" \
    --load "$__testing__scorecard__RULES" || return 1

  log "$__testing__scorecard__render__text"
  @unlet __testing__scorecard__render__ configured rollout
  @unlet __testing__scorecard__render__ selected_tests selectable_tests seconds_saved clean_streak last_escape_at clean_streak_goal
}

:<<'FUN'
The repo's tracked files as a struct array of $PROJ-relative paths. Delegates
to git__tracked_files (git index in a work tree, hidden-pruned find otherwise).
FUN
__testing__scorecard__tracked_files() {
  __testing__scorecard__tracked_files__names="$(git__tracked_files "$PROJ")" || return 1
  @split __testing__scorecard__tracked_files__out "$__testing__scorecard__tracked_files__names"
  println "$__testing__scorecard__tracked_files__out"
}

:<<'FUN'
Unmapped tracked source files for an areas object: {files: [...], top_level:
{...}}. Files under a suite root are excluded -- the orphan check owns the test
trees -- so the effective suites are passed through to read those roots from.

args:
  $1  The areas object
  $2  The effective suites
  $3  The tracked files (struct array)
FUN
__testing__scorecard__unmapped() {
  @run_awk __testing__scorecard__unmapped__out "$__testing__scorecard__UNMAPPED" \
    "$1" \
    --with "$3" \
    --with "$2" \
    --load "$__testing__scorecard__RULES" || return 1
  println "$__testing__scorecard__unmapped__out"
}

:<<'FUN'
Area paths that do not exist on disk, as an array of missing-path findings.
One awk pass prints every area x path pair; the existence test itself is the
shell builtin [ -e ], so a clean mapping pays no per-path process.

args:
  $1  The areas object
FUN
__testing__scorecard__missing_paths() {
  @run_awk __testing__scorecard__missing_paths__pairs "$__testing__scorecard__AREA_PATHS" "$1" || return 1
  @arr __testing__scorecard__missing_paths__acc || return 1
  while IFS="$__testing__scorecard__TAB" read -r \
    __testing__scorecard__missing_paths__area \
    __testing__scorecard__missing_paths__path
  do
    [ -n "$__testing__scorecard__missing_paths__path" ] || continue
    [ -e "$PROJ/$__testing__scorecard__missing_paths__path" ] && continue
    __testing__scorecard__missing_paths__finding="$(__testing__scorecard__missing_path_finding \
      "$__testing__scorecard__missing_paths__area" \
      "$__testing__scorecard__missing_paths__path"
    )" || return 1
    @push __testing__scorecard__missing_paths__acc \
      "$__testing__scorecard__missing_paths__acc" \
      "$__testing__scorecard__missing_paths__finding" || return 1
  done <<EOF
$__testing__scorecard__missing_paths__pairs
EOF
  println "$__testing__scorecard__missing_paths__acc"
}

:<<'FUN'
Explicit test entries (the manifest's per-area .tests overrides) that name
nothing in the tracked tree, as an array of dead-test findings. Every area x
suite x entry is judged in the one dead_tests.awk pass.

args:
  $1  The areas object (pre-attach, so .tests is exactly what the manifest
      declared)
  $2  The tracked files (struct array)
FUN
__testing__scorecard__dead_tests() {
  @run_awk __testing__scorecard__dead_tests__out "$__testing__scorecard__DEAD_TESTS" \
    "$1" \
    --with "$2" \
    --load "$__testing__scorecard__RULES" || return 1
  println "$__testing__scorecard__dead_tests__out"
}

:<<'FUN'
Orphan tests per suite: files under the suite root matching the suite globs
that no area's attached tests include, as {"<suite>": [<file>, ...]}. Suites
with no root (an unregistered or layout-less runner) and suites with no
orphans are absent. Every suite's universe and diff is the one orphans.awk
pass.

args:
  $1  The attached areas (every .tests filled in)
  $2  The effective suites
  $3  The tracked files (struct array)
FUN
__testing__scorecard__orphans() {
  @run_awk __testing__scorecard__orphans__out "$__testing__scorecard__ORPHANS" \
    "$1" \
    --with "$3" \
    --with "$2" \
    --load "$__testing__scorecard__RULES" || return 1
  println "$__testing__scorecard__orphans__out"
}

:<<'FUN'
Per-area summary rows from the attached areas, as an array of rows.

args:
  $1  The attached areas
FUN
__testing__scorecard__area_rows() {
  @run_awk __testing__scorecard__area_rows__out "$__testing__scorecard__AREA_ROWS" \
    "$1" \
    --load "$__testing__scorecard__RULES" || return 1
  println "$__testing__scorecard__area_rows__out"
}

:<<'FUN'
@reduce callback: adds one array's length to a running count.

args:
  $1  The accumulator (running total)
  $2  The array
FUN
__testing__scorecard__add_len() {
  __testing__scorecard__add_len__total="$1"
  @len __testing__scorecard__add_len__len "$2" || return 1
  echo "$(( __testing__scorecard__add_len__total + __testing__scorecard__add_len__len ))"
}

:<<'FUN'
The number of findings an array-valued gap field holds.

args:
  $1  The gaps block
  $2  The field path
FUN
__testing__scorecard__gap_count() {
  @arr __testing__scorecard__gap_count__arr_14
  @get __testing__scorecard__gap_count__findings "$1" "$2" "$__testing__scorecard__gap_count__arr_14" || return 1
  @len __testing__scorecard__gap_count__out "$__testing__scorecard__gap_count__findings"
  println "$__testing__scorecard__gap_count__out"
}

:<<'FUN'
The number of orphan tests across every suite.

args:
  $1  The gaps block
FUN
__testing__scorecard__orphan_count() {
  @obj __testing__scorecard__orphan_count__obj_15
  @get __testing__scorecard__orphan_count__by_suite "$1" '.orphans' "$__testing__scorecard__orphan_count__obj_15" || return 1
  @values __testing__scorecard__orphan_count__lists "$__testing__scorecard__orphan_count__by_suite" || return 1
  @reduce __testing__scorecard__orphan_count__out __testing__scorecard__add_len "$__testing__scorecard__orphan_count__lists" 0
  println "$__testing__scorecard__orphan_count__out"
}

:<<'FUN'
The gap counts of a report, one per category, as a struct object.

args:
  $1  The gaps block
FUN
__testing__scorecard__gap_counts() {
  __testing__scorecard__gap_counts__unmapped="$(__testing__scorecard__gap_count "$1" '.unmapped.files')" || return 1
  __testing__scorecard__gap_counts__missing="$(__testing__scorecard__gap_count "$1" '.missing_paths')" || return 1
  __testing__scorecard__gap_counts__dead="$(__testing__scorecard__gap_count "$1" '.dead_tests')" || return 1
  __testing__scorecard__gap_counts__orphans="$(__testing__scorecard__orphan_count "$1")" || return 1
  __testing__scorecard__gap_counts__untested="$(__testing__scorecard__gap_count "$1" '.untested_areas')" || return 1
  __testing__scorecard__gap_counts__undeclared="$(__testing__scorecard__gap_count "$1" '.undeclared_dirs')" || return 1

  @obj __testing__scorecard__gap_counts__out \
    '.unmapped_files' "$__testing__scorecard__gap_counts__unmapped" \
    '.missing_paths' "$__testing__scorecard__gap_counts__missing" \
    '.dead_tests' "$__testing__scorecard__gap_counts__dead" \
    '.orphan_tests' "$__testing__scorecard__gap_counts__orphans" \
    '.untested_areas' "$__testing__scorecard__gap_counts__untested" \
    '.undeclared_dirs' "$__testing__scorecard__gap_counts__undeclared"
  println "$__testing__scorecard__gap_counts__out"
}

:<<'FUN'
The ready verdict for a set of gap counts: true when every gating count is
zero, including untested areas. Undeclared directories are advisory and are
not read.

args:
  $1  The gap counts
FUN
__testing__scorecard__ready() {
  @get __testing__scorecard__ready__get_16 "$1" '.unmapped_files'
  @get __testing__scorecard__ready__get_17 "$1" '.missing_paths'
  @get __testing__scorecard__ready__get_18 "$1" '.dead_tests'
  @get __testing__scorecard__ready__get_19 "$1" '.orphan_tests'
  @get __testing__scorecard__ready__get_20 "$1" '.untested_areas'
  __testing__scorecard__ready__gaps="$(( \
    __testing__scorecard__ready__get_16 \
    + __testing__scorecard__ready__get_17 \
    + __testing__scorecard__ready__get_18 \
    + __testing__scorecard__ready__get_19 \
    + __testing__scorecard__ready__get_20 \
  ))"

  if [ "$__testing__scorecard__ready__gaps" -eq 0 ]; then
    @true __testing__scorecard__ready__out
    println "$__testing__scorecard__ready__out"
  else
    @false __testing__scorecard__ready__out
    println "$__testing__scorecard__ready__out"
  fi
}

:<<'FUN'
The summary block: the area count, the per-category gap counts and the ready
verdict. The verdict reads the mapping gaps -- unmapped files, missing paths,
dead entries, orphans, untested areas -- and is true when each is zero; the
undeclared-directory count is carried beside them and never gates.

args:
  $1  The area rows
  $2  The gaps block
FUN
__testing__scorecard__summary() {
  __testing__scorecard__summary__counts="$(__testing__scorecard__gap_counts "$2")" || return 1
  @len __testing__scorecard__summary__areas "$1" || return 1
  __testing__scorecard__summary__ready="$(__testing__scorecard__ready "$__testing__scorecard__summary__counts")" || return 1

  __testing__scorecard__summary_block \
    "$__testing__scorecard__summary__areas" \
    "$__testing__scorecard__summary__counts" \
    "$__testing__scorecard__summary__ready"
}
