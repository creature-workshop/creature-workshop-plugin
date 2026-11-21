#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/testing/api.sh" \
  "$SHELLOPS_DIR/lib/testing/selectors/api.sh" \
  "$SHELLOPS_DIR/lib/testing/escapes.sh" \
  "$SHELLOPS_DIR/lib/testing/metrics/api.sh" \
  "$SHELLOPS_DIR/lib/testing/shard.sh" \
  "$SHELLOPS_DIR/lib/areas/api.sh" \
  "$SHELLOPS_DIR/lib/fingerprint/api.sh" \
  "$SHELLOPS_DIR/lib/http/api.sh"

:<<'MODULE'
Label-driven impacted-test dispatch for Test Impact Analysis (TIA).

Reads area/* labels from a code review, resolves the per-suite test files for
those areas through the resolver, and dispatches each suite to its framework
runner.

Selection is the selectors' (lib/testing/selectors/api.sh): the run is the
union of their answers, and a file no selector claims widens it. What stays
here sits above selection: the widening rules, the net-new rule, and the
plan a run executes. Only the label read touches the network, behind
__testing__dispatch__fetch_labels, so the routing is unit-testable.

Suite -> runner mapping: a resolved test set is suite-keyed ({"<suite>": [files]}).
Each suite in the areas `suites` config carries a "runner" field naming the
runner that executes it (e.g. {"bats": {"runner": "bats", ...}}); the runner
defaults to the suite key when absent. Dispatch looks the runner up per suite and
forwards the suite's files as positional arguments to testing__run, which the
registered <runner>_run_selected consumes.

Every dispatched run leaves a metrics record behind (lib/testing/metrics/api.sh):
the decision it reached, the suites it ran, and how long they took.

Usage:
  import "$SHELLOPS_DIR/lib/testing/dispatch.sh"
  import "$SHELLOPS_DIR/lib/testing/frameworks/bats/bats.runner.op.sh"   # register runners
  import "$SHELLOPS_DIR/lib/testing/frameworks/cargo/cargo.runner.op.sh"

  testing__run_impacted "$area_names"           # resolve + dispatch for explicit areas
  testing__plan "$area_names"                   # resolve only: print the plan, run nothing
  names="$(testing__area_names_from_review)"    # read area/* labels off the review
MODULE

# The read token, as the chain testing__review_labels falls back through.
fingerprint__secret FORGE_TOKEN GITLAB_TOKEN FORGE_PR_TOKEN CI_JOB_TOKEN

: <<'CONST'
Co-located filter that unions two suite-keyed selection maps, resolved under
$SHELLOPS_DIR.
CONST
__testing__dispatch__MERGE_SELECTED="$SHELLOPS_DIR/lib/testing/merge_selected.awk"

# CONST: The newline a struct array of files is joined with to deal it.
__testing__dispatch__NL='
'

# CONST: The review label that forces a full run, bypassing impacted-test selection.
__testing__dispatch__FULL_SUITE_LABEL="testing/full-suite"

: <<'CONST'
The awk program that classifies an edit of the testing config between a
review's base and head as additive or remapping.
CONST
__testing__dispatch__CONFIG_EDIT="$SHELLOPS_DIR/lib/testing/config_edit.awk"

:<<'FUN'
Logs the decision announcement and prints the plan the caller will execute.

Naming the decision in one place is what lets the metrics record say *why* a run
was wide, rather than only that it was: every widening path is a distinct reason
in schema/testing-metrics.schema.json.

  $1 mode  $2 reason  $3 dispatch  $4 log line  $5 run
  $6 suites (optional)  $7 selected (optional)
  run is one of: none | all_frameworks | full_suites | selected
FUN
__testing__dispatch__decide() {
  log "testing/dispatch: $4"
  @obj __testing__dispatch__decide__obj_1
  @obj __testing__dispatch__decide__obj_2
  @obj __testing__dispatch__decide__out '.mode' "$1" '.reason' "$2" '.dispatch' "$3" '.run' "$5" \
    '.suites' "${6:-$__testing__dispatch__decide__obj_1}" '.selected' "${7:-$__testing__dispatch__decide__obj_2}"
  println "$__testing__dispatch__decide__out"
}

:<<'PUB_FUN'
Maps a list of code-review label names to the sorted, unique area names they
encode: keeps only the area/* labels and strips the prefix.

  labels  [<label>, ...]  the review's full label set

Usage: testing__areas_from_labels "$labels"
PUB_FUN
testing__areas_from_labels() {
  @filter __testing__areas_from_labels__filter_3 "$1" silt__text_starts_with . area/
  @map __testing__areas_from_labels__map_4 __testing__dispatch__strip_area_prefix "$__testing__areas_from_labels__filter_3"
  @unique __testing__areas_from_labels__out "$__testing__areas_from_labels__map_4"
  println "$__testing__areas_from_labels__out"
}

:<<'FUN'
@map callback: one area/* label (wrapped) to its bare area name.

  $1 label (wrapped)
FUN
__testing__dispatch__strip_area_prefix() {
  @unwrap __testing__dispatch__strip_area_prefix__label "$1"
  printf '%s' "${__testing__dispatch__strip_area_prefix__label#area/}"
}

:<<'PUB_FUN'
Prints the struct boolean for whether a review's label set carries the
testing/full-suite label.

  labels  [<label>, ...]  the review's full label set

Usage: if @is_true "$(testing__labels_force_full "$labels")"; then ... fi
PUB_FUN
testing__labels_force_full() {
  @arr __testing__labels_force_full__arr_5 "$__testing__dispatch__FULL_SUITE_LABEL"
  @intersect __testing__labels_force_full__intersect_6 "$1" "$__testing__labels_force_full__arr_5"
  @len __testing__labels_force_full__len_7 "$__testing__labels_force_full__intersect_6"
  @succeeds __testing__labels_force_full__out [ "$__testing__labels_force_full__len_7" -gt 0 ]
  println "$__testing__labels_force_full__out"
}

:<<'FUN'
Prints the struct boolean for whether the full suite is forced for the run,
bypassing selection: the caller passed options carrying force_full, or
TESTING_FULL_SUITE is set in the environment.

  $1 options ({force_full}, optional)
FUN
__testing__dispatch__full_suite_forced() {
  if @defined "${TESTING_FULL_SUITE:-}"; then
    @true __testing__dispatch__full_suite_forced__out
    println "$__testing__dispatch__full_suite_forced__out"
    return
  fi

  @obj __testing__dispatch__full_suite_forced__obj_8
  @get __testing__dispatch__full_suite_forced__get_9 "${1:-$__testing__dispatch__full_suite_forced__obj_8}" '.force_full'
  @succeeds __testing__dispatch__full_suite_forced__out @is_true "$__testing__dispatch__full_suite_forced__get_9"
  println "$__testing__dispatch__full_suite_forced__out"
}

:<<'FUN'
Prints the struct boolean for whether the run is to select the named areas'
own tests alone: the caller passed options carrying own, as a site running an
adaptor's floor does. A review never asks this; a change to a module runs
what depends on it.

  $1 options ({own}, optional)
FUN
__testing__dispatch__own_asked() {
  @obj __testing__dispatch__own_asked__obj_10
  @get __testing__dispatch__own_asked__get_11 "${1:-$__testing__dispatch__own_asked__obj_10}" '.own'
  @succeeds __testing__dispatch__own_asked__out @is_true "$__testing__dispatch__own_asked__get_11"
  println "$__testing__dispatch__own_asked__out"
}

:<<'FUN'
Prints the struct boolean for whether an area in a picked area map carries
full_suite: true. Such an area is depended on more widely than its own paths,
so a path-scoped selection would under-test it.
FUN
__testing__dispatch__any_full_suite() {
  @values __testing__dispatch__any_full_suite__values_12 "$1"
  @filter __testing__dispatch__any_full_suite__filter_13 "$__testing__dispatch__any_full_suite__values_12" silt__text_is .full_suite true
  @len __testing__dispatch__any_full_suite__len_14 "$__testing__dispatch__any_full_suite__filter_13"
  @succeeds __testing__dispatch__any_full_suite__out [ "$__testing__dispatch__any_full_suite__len_14" -gt 0 ]
  println "$__testing__dispatch__any_full_suite__out"
}

:<<'FUN'
The log phrase for a run widened by full_suite areas: each area with the
changed files that reached it, so the line says what would narrow the run.

  __testing__dispatch__widened_line '[{"area":"lib","files":["lib/git/api.sh"]}]'
  -> area lib is tagged full_suite, reached through lib/git/api.sh

  $1 widened_by (struct array of {area, files})
FUN
__testing__dispatch__widened_line() {
  @map __testing__dispatch__widened_line__map_15 __testing__dispatch__widened_area "$1"
  @join __testing__dispatch__widened_line__out "$__testing__dispatch__widened_line__map_15" "; "
  println "$__testing__dispatch__widened_line__out"
}

:<<'FUN'
@map callback: one widened area as its phrase. An area no changed file
reached was picked by its label alone, and the phrase says so.

  $1 {area, files}
FUN
__testing__dispatch__widened_area() {
  @let "$1" __testing__dispatch__widened_area__ area files
  if @empty "$__testing__dispatch__widened_area__files"; then
    __testing__dispatch__widened_area__phrase="area $__testing__dispatch__widened_area__area is tagged full_suite, reached by its label alone"
  else
    @join __testing__dispatch__widened_area__join_16 "$__testing__dispatch__widened_area__files" ", "
    __testing__dispatch__widened_area__phrase="area $__testing__dispatch__widened_area__area is tagged full_suite, reached through $__testing__dispatch__widened_area__join_16"
  fi
  @unlet __testing__dispatch__widened_area__ area files
  @wrap __testing__dispatch__widened_area__out "$__testing__dispatch__widened_area__phrase"
  println "$__testing__dispatch__widened_area__out"
}

:<<'FUN'
Prints the struct boolean for whether the review has mapping drift: an unmapped
changed file git did not report as added -- an edit, removal, rename, or copy
of code the config lost track of, whose dependents are unknown.

  $1 unmapped files (struct array)   $2 added files (struct array)
FUN
__testing__dispatch__has_drift() {
  @difference __testing__dispatch__has_drift__difference_17 "$1" "$2"
  @len __testing__dispatch__has_drift__len_18 "$__testing__dispatch__has_drift__difference_17"
  @succeeds __testing__dispatch__has_drift__out [ "$__testing__dispatch__has_drift__len_18" -gt 0 ]
  println "$__testing__dispatch__has_drift__out"
}

:<<'FUN'
True (0) when the review changes at least one file and every changed file is
added; false for an empty review or one with any edit, removal, rename, or copy.

  $1 changed files (struct array)   $2 added files (struct array)
FUN
__testing__dispatch__pure_net_new() {
  @len __testing__dispatch__pure_net_new__changed "$1"
  if [ "$__testing__dispatch__pure_net_new__changed" -eq 0 ]; then
    return 1
  fi
  @difference __testing__dispatch__pure_net_new__edited "$1" "$2"
  @len __testing__dispatch__pure_net_new__edited_count "$__testing__dispatch__pure_net_new__edited"
  [ "$__testing__dispatch__pure_net_new__edited_count" -eq 0 ]
}

:<<'PUB_FUN'
True when a set of changed paths includes the active testing-config file -- the
file areas__load_areas_config resolves the areas/suites from (areas__config_path: an
inline manifest, a named testmap, or the sibling testmap.json). The caller then
classifies the edit (testing__config_edit): one that only adds cannot change what
an existing area selects, while any other cannot be trusted to map its own
change and runs the full suite. False when the repo resolves no config path or
the config file is untouched.

  changed_paths  [<file>, ...]

Usage: testing__config_changed "$changed_paths"
PUB_FUN
testing__config_changed() {
  __testing__config_changed__path="$(areas__config_path)"
  @defined "$__testing__config_changed__path" || return 1

  @arr __testing__config_changed__arr_22 "$__testing__config_changed__path"
  @intersect __testing__config_changed__hits "$1" \
    "$__testing__config_changed__arr_22"
  @len __testing__config_changed__len_23 "$__testing__config_changed__hits"
  [ "$__testing__config_changed__len_23" -gt 0 ]
}

:<<'PUB_FUN'
Classifies the edit a testing config took from one version to another:
additive when it only adds areas, tests on an area, or suites, or drops tests
from an area; remapping when it changes what an existing area or suite
selects (a source path, a full_suite or inert flag, a suite's configuration,
or an area's removal). Prints the kind, the areas the edit added, one line
per remapping it found, and how far the remapping reaches: the head areas to
select for when every remapping is an area's and every removed area's path
has an area at head, or the full suite when a suite or a setting changed or
a removed path has none.

  testing__config_edit "$base" "$head"
  ->  {"kind": "additive", "added_areas": ["lib.beta"], "remapped": [], "scope": "none", "widen_to": []}
  ->  {"kind": "remapping", "added_areas": [], "remapped": ["area lib.alpha remapped"], "scope": "areas", "widen_to": ["lib.alpha"]}

  base  The config before the edit (from areas__load_areas_config or areas__config_at_ref)
  head  The config after it

Usage: testing__config_edit "$base_config" "$head_config"
PUB_FUN
testing__config_edit() {
  __testing__config_edit__base_areas="$(areas__compute_areas "$1")" || return 1
  __testing__config_edit__head_areas="$(areas__compute_areas "$2")" || return 1
  @obj __testing__config_edit__obj_24 '.config' "$1" '.areas' "$__testing__config_edit__base_areas"
  @obj __testing__config_edit__obj_25 '.config' "$2" '.areas' "$__testing__config_edit__head_areas"
  @obj __testing__config_edit__obj_26 \
    '.base' "$__testing__config_edit__obj_24" \
    '.head' "$__testing__config_edit__obj_25"
  @run_awk __testing__config_edit__out "$__testing__dispatch__CONFIG_EDIT" "$__testing__config_edit__obj_26" \
    --load "$SHELLOPS_DIR/lib/structs/silt/tree_equal.awk" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" || return 1
  println "$__testing__config_edit__out"
}

:<<'FUN'
The config edit a review carries, for the plan to act on: untouched when the
review leaves the config alone; the classified edit (testing__config_edit) when
the caller supplied the config at the review's base in the options; remapping
when the config changed and no base is known, since an edit that cannot be
compared cannot be trusted to have only added.

  $1 changed paths   $2 options ({base_config}, optional)   $3 the config at head
FUN
__testing__dispatch__config_edit_for() {
  if ! testing__config_changed "$1"; then
    @wrap __testing__dispatch__config_edit_for__wrap_27 untouched
    @arr __testing__dispatch__config_edit_for__arr_28
    @arr __testing__dispatch__config_edit_for__arr_29
    @wrap __testing__dispatch__config_edit_for__wrap_30 none
    @arr __testing__dispatch__config_edit_for__arr_31
    @obj __testing__dispatch__config_edit_for__out \
      '.kind' "$__testing__dispatch__config_edit_for__wrap_27" \
      '.added_areas' "$__testing__dispatch__config_edit_for__arr_28" \
      '.remapped' "$__testing__dispatch__config_edit_for__arr_29" \
      '.scope' "$__testing__dispatch__config_edit_for__wrap_30" \
      '.widen_to' "$__testing__dispatch__config_edit_for__arr_31"
    println "$__testing__dispatch__config_edit_for__out"
    return 0
  fi

  @obj __testing__dispatch__config_edit_for__obj_32
  @get __testing__dispatch__config_edit_for__base "${2:-$__testing__dispatch__config_edit_for__obj_32}" '.base_config' 'null'
  if ! @defined "$__testing__dispatch__config_edit_for__base"; then
    @wrap __testing__dispatch__config_edit_for__wrap_33 remapping
    @arr __testing__dispatch__config_edit_for__arr_34
    @arr __testing__dispatch__config_edit_for__arr_35 "the config at the review's base is unknown"
    @wrap __testing__dispatch__config_edit_for__wrap_36 full
    @arr __testing__dispatch__config_edit_for__arr_37
    @obj __testing__dispatch__config_edit_for__out \
      '.kind' "$__testing__dispatch__config_edit_for__wrap_33" \
      '.added_areas' "$__testing__dispatch__config_edit_for__arr_34" \
      '.remapped' "$__testing__dispatch__config_edit_for__arr_35" \
      '.scope' "$__testing__dispatch__config_edit_for__wrap_36" \
      '.widen_to' "$__testing__dispatch__config_edit_for__arr_37"
    println "$__testing__dispatch__config_edit_for__out"
    return 0
  fi

  testing__config_edit "$__testing__dispatch__config_edit_for__base" "$3"
}

:<<'FUN'
The log phrase for a run widened by a remapping config edit: the config file
and each remapping the classifier named, so the line says which edit widened
the run.

  __testing__dispatch__remapped_line '["area lib.alpha remapped","suite unit changed"]'
  -> the testing config (testmap.json) remapped: area lib.alpha remapped; suite unit changed

  $1 remapped (struct array of phrases)
FUN
__testing__dispatch__remapped_line() {
  @join __testing__dispatch__remapped_line__join_38 "$1" "; "
  printf '%s' "the testing config ($(areas__config_path)) remapped: $__testing__dispatch__remapped_line__join_38"
}

:<<'FUN'
The log phrase for a run whose config edit only added: the config file and the
areas it added, or that it added none (new tests or suites alone).

  __testing__dispatch__additive_line '["lib.beta"]'
  -> the testing config (testmap.json) changed additively, adding area(s) lib.beta

  $1 added areas (struct array of names)
FUN
__testing__dispatch__additive_line() {
  if @empty "$1"; then
    printf '%s' "the testing config ($(areas__config_path)) changed additively, adding no area"
    return 0
  fi
  @join __testing__dispatch__additive_line__join_39 "$1" ", "
  printf '%s' "the testing config ($(areas__config_path)) changed additively, adding area(s) $__testing__dispatch__additive_line__join_39"
}

:<<'PUB_FUN'
Resolves the impacted tests for a set of areas and dispatches each suite to its
runner. The overall exit code is non-zero if any suite failed.

With no testing config it runs the full suite (every registered framework): a
repo opts into selection by adding a testing block, never out of it. With one,
the full suite runs when it is forced, when no area/* label is present, or
when the config edit reaches it (testing__config_edit says when). An additive
edit selects as the labels ask with the added areas joined in, and a
remapping selects the remapped areas too. A changed file under no area is
mapping drift and runs the full suite, unless it is an added file in a purely
net-new review, which runs those files' own derived tests.

Parameters:
  area_names    [<area>, ...]  bare area names (e.g. from testing__areas_from_labels)
  changed_paths [<file>, ...]  the review's changed files (optional, empty default)
  added_paths   [<file>, ...]  the subset git reports as added (optional, empty)
  options       {force_full, own, base_config}  force_full runs the full
                suite, as if TESTING_FULL_SUITE were set; own runs the named
                areas' own tests and none of their importers', as a site
                running an adaptor's floor asks; base_config is the testing
                config at the review's base, read to classify an edit to it
                (all optional)

Usage: testing__run_impacted "$area_names" ["$changed_paths" ["$added_paths" ["$options"]]]
PUB_FUN
testing__run_impacted() {
  __testing__run_impacted__run="$(testing__metrics__begin)"
  __testing__run_impacted__plan="$(testing__plan "$@")" || return $?

  # __testing__dispatch__execute prints the suite rows on stdout and streams the
  # live test output on fd 3, so the capture takes only the rows. The group
  # points fd 3 at the caller's stdout for exactly the capture's duration.
  __testing__run_impacted__status=0
  {
    __testing__run_impacted__rows="$(__testing__dispatch__execute \
      "$__testing__run_impacted__plan"
    )"
  } \
    3>&1 \
    || __testing__run_impacted__status=$?

  @arr __testing__run_impacted__arr_40
  __testing__dispatch__record_run \
    "$__testing__run_impacted__run" \
    "$__testing__run_impacted__plan" \
    "${1:-$__testing__run_impacted__arr_40}" \
    "$__testing__run_impacted__status" \
    "$__testing__run_impacted__rows"
  return "$__testing__run_impacted__status"
}

:<<'FUN'
Leaves the run's metrics record behind: the run context, the decision the plan
reached for the areas asked about, whether the run passed, and its suite rows.
Never affects the run's result -- emit swallows its own failures, and the
record's path stays out of this function's output.

  $1 run context   $2 plan   $3 areas   $4 exit status   $5 suite rows
FUN
__testing__dispatch__record_run() {
  testing__metrics__emit \
    "$1" \
    "$(__testing__dispatch__decision "$2" "$3" "$4")" \
    "$5" \
    > /dev/null
}

:<<'FUN'
The decision testing__metrics__emit records: the plan's mode, reason, and
dispatch flag, the areas the caller asked for, whether the run passed, and,
when the plan names them, the full_suite areas that widened it, the config
edit it classified with the remappings it found, and what each selector
claimed and contributed.

  $1 plan   $2 areas   $3 exit status
FUN
__testing__dispatch__decision() {
  @let "$1" __testing__dispatch__decision__ mode reason dispatch widened_by config_edit remapped selectors

  @obj __testing__dispatch__decision__built \
    '.mode' "$__testing__dispatch__decision__mode" \
    '.reason' "$__testing__dispatch__decision__reason" \
    '.dispatch' "$__testing__dispatch__decision__dispatch" \
    '.areas' "$2" \
    '.status' "$(__testing__dispatch__status_word "$3")"
  __testing__dispatch__decision__status=$?
  if @defined "$__testing__dispatch__decision__widened_by"; then
    @set __testing__dispatch__decision__built \
      "$__testing__dispatch__decision__built" \
      '.widened_by' \
      "$__testing__dispatch__decision__widened_by"
    __testing__dispatch__decision__status=$?
  fi
  if @defined "$__testing__dispatch__decision__config_edit"; then
    @set __testing__dispatch__decision__built \
      "$__testing__dispatch__decision__built" \
      '.config_edit' \
      "$__testing__dispatch__decision__config_edit"
    __testing__dispatch__decision__status=$?
  fi
  if @defined "$__testing__dispatch__decision__remapped"; then
    @set __testing__dispatch__decision__built \
      "$__testing__dispatch__decision__built" \
      '.remapped' \
      "$__testing__dispatch__decision__remapped"
    __testing__dispatch__decision__status=$?
  fi
  if @defined "$__testing__dispatch__decision__selectors"; then
    @set __testing__dispatch__decision__built \
      "$__testing__dispatch__decision__built" \
      '.selectors' \
      "$__testing__dispatch__decision__selectors"
    __testing__dispatch__decision__status=$?
  fi
  @unlet __testing__dispatch__decision__ mode reason dispatch widened_by config_edit remapped selectors
  println "$__testing__dispatch__decision__built"
  return "$__testing__dispatch__decision__status"
}

:<<'FUN'
A run's exit status as the word the metrics record spells it with.

  $1 exit status
FUN
__testing__dispatch__status_word() {
  case "$1" in
    0) printf 'passed\n' ;;
    *) printf 'failed\n' ;;
  esac
}

:<<'PUB_FUN'
Resolves the selection and prints the plan; it does not run tests. Same
arguments as testing__run_impacted. Returns 1 without a plan when the suites
config is invalid.

The plan settles what the config allows first -- no config, a forced run, a
config edit that reaches the whole suite -- and hands everything else to the
selection stage (__testing__dispatch__plan_selection) with the review's area
names, the areas an additive edit added and the areas a remapping reaches
joined in. A plan reached through a config edit carries config_edit, and a
remapping's phrases as remapped, so its record says which edit the run was
classified or widened by.

Usage: testing__plan "$area_names" ["$changed_paths" ["$added_paths" ["$options"]]]
PUB_FUN
testing__plan() {
  @arr __testing__plan__arr_41
  __testing__plan__changed="${2:-$__testing__plan__arr_41}"
  @arr __testing__plan__arr_42
  __testing__plan__added="${3:-$__testing__plan__arr_42}"
  @obj __testing__plan__obj_43
  __testing__plan__options="${4:-$__testing__plan__obj_43}"
  __testing__plan__config="$(areas__load_areas_config)"

  # No testing config: the repo has not opted into selection, so run the full
  # suite rather than nothing.
  if ! @defined "$__testing__plan__config"; then
    @false __testing__plan__false_44
    __testing__dispatch__decide full_suite no_config "$__testing__plan__false_44" \
      "no testing config -- running the full suite for every framework." \
      all_frameworks
    return 0
  fi

  @let "$__testing__plan__config" __testing__plan__ dispatch suites
  @defined "$__testing__plan__dispatch" || @false __testing__plan__dispatch
  @defined "$__testing__plan__suites" || @obj __testing__plan__suites

  if ! testing__validate_suites "$__testing__plan__suites"; then
    error "testing/dispatch: invalid testing.suites config (see schema errors above)."
    return 1
  fi

  # Overlay each suite's manifest overrides on its runner defaults, so resolution
  # and dispatch see a complete suite even when the manifest only names a runner.
  __testing__plan__suites="$(testing__effective_suites \
    "$__testing__plan__suites")"

  if @is_true "$(__testing__dispatch__full_suite_forced "$__testing__plan__options")"; then
    __testing__dispatch__decide full_suite forced \
      "$__testing__plan__dispatch" \
      "full suite forced -- running every runner in full." \
      full_suites \
      "$__testing__plan__suites"
    return 0
  fi

  __testing__plan__edit="$(__testing__dispatch__config_edit_for \
    "$__testing__plan__changed" \
    "$__testing__plan__options" \
    "$__testing__plan__config"
  )" || return 1
  @let "$__testing__plan__edit" __testing__plan__edit__ kind added_areas remapped scope widen_to

  if [ "$__testing__plan__edit__scope" = full ]; then
    __testing__plan__plan="$(__testing__dispatch__plan_for_full_edit \
      "$__testing__plan__dispatch" \
      "$__testing__plan__suites" \
      "$__testing__plan__edit"
    )"
    __testing__plan__status=$?
  else
    @obj __testing__plan__obj_45 \
      '.changed' "$__testing__plan__changed" \
      '.added' "$__testing__plan__added" \
      '.config' "$__testing__plan__config" \
      '.suites' "$__testing__plan__suites" \
      '.dispatch' "$__testing__plan__dispatch" \
      '.own' "$(__testing__dispatch__own_asked "$__testing__plan__options")"
    __testing__plan__plan="$(__testing__dispatch__plan_for_edit "$1" "$__testing__plan__edit" "$__testing__plan__obj_45")"
    __testing__plan__status=$?
  fi
  @unlet __testing__plan__ dispatch suites
  @unlet __testing__plan__edit__ kind added_areas remapped scope widen_to
  @is_zero "$__testing__plan__status" || return 1
  println "$__testing__plan__plan"
}

:<<'FUN'
Prints the plan for a config edit that reaches the full suite: every runner
in full, decided as config_changed, carrying the edit's kind and its
remappings so the record says which edit widened the run.

  $1 dispatch flag   $2 the effective suites   $3 the classified edit
FUN
__testing__dispatch__plan_for_full_edit() {
  @let "$3" __testing__dispatch__plan_for_full_edit__ kind remapped
  __testing__dispatch__plan_for_full_edit__plan="$(__testing__dispatch__decide full_suite config_changed \
    "$1" \
    "$(__testing__dispatch__remapped_line "$__testing__dispatch__plan_for_full_edit__remapped") -- running the full suite for every runner." \
    full_suites \
    "$2"
  )"
  __testing__dispatch__plan_for_full_edit__plan="$(__testing__dispatch__with_config_edit \
    "$__testing__dispatch__plan_for_full_edit__plan" \
    "$__testing__dispatch__plan_for_full_edit__kind" \
    "$__testing__dispatch__plan_for_full_edit__remapped"
  )"
  @unlet __testing__dispatch__plan_for_full_edit__ kind remapped
  println "$__testing__dispatch__plan_for_full_edit__plan"
}

:<<'FUN'
Prints the plan the selection stage makes for the review's <names> under a
config <edit> that does not reach the full suite: the names the edit adds
joined in, and the edit's kind and remappings set on the plan when the
config was touched.

  $1 names   $2 the classified edit   $3 the selection context without names
     ({changed, added, config, suites, dispatch, own})
FUN
__testing__dispatch__plan_for_edit() {
  @let "$2" __testing__dispatch__plan_for_edit__ kind remapped
  __testing__dispatch__plan_for_edit__names="$(__testing__dispatch__names_for_edit "$1" "$2")"
  @set __testing__dispatch__plan_for_edit__set_46 "$3" '.names' "$__testing__dispatch__plan_for_edit__names"
  __testing__dispatch__plan_for_edit__plan="$(__testing__dispatch__plan_selection \
    "$__testing__dispatch__plan_for_edit__set_46"
  )"
  __testing__dispatch__plan_for_edit__status=$?
  if [ "$__testing__dispatch__plan_for_edit__status" -eq 0 ] && [ "$__testing__dispatch__plan_for_edit__kind" != untouched ]; then
    __testing__dispatch__plan_for_edit__plan="$(__testing__dispatch__with_config_edit \
      "$__testing__dispatch__plan_for_edit__plan" \
      "$__testing__dispatch__plan_for_edit__kind" \
      "$__testing__dispatch__plan_for_edit__remapped"
    )"
    __testing__dispatch__plan_for_edit__status=$?
  fi
  @unlet __testing__dispatch__plan_for_edit__ kind remapped
  @is_zero "$__testing__dispatch__plan_for_edit__status" || return 1
  println "$__testing__dispatch__plan_for_edit__plan"
}


:<<'FUN'
Prints the area names the selection stage is to select for, given the
review's <names> and the classified config <edit>: the names alone when the
config is untouched, the added areas joined in for an additive edit, and the
added areas and the areas the remapping reaches joined in for a remapping,
each logged as the reason the run selects.

  $1 names (struct array)   $2 the classified edit ({kind, added_areas, remapped, scope, widen_to})
FUN
__testing__dispatch__names_for_edit() {
  @let "$2" __testing__dispatch__names_for_edit__ kind added_areas remapped widen_to
  __testing__dispatch__names_for_edit__names="$1"
  case "$__testing__dispatch__names_for_edit__kind" in
    additive) __testing__dispatch__names_for_edit__names="$(__testing__dispatch__names_additive "$1" "$__testing__dispatch__names_for_edit__added_areas")" ;;
    remapping) __testing__dispatch__names_for_edit__names="$(__testing__dispatch__names_remapping "$1" "$__testing__dispatch__names_for_edit__added_areas" "$__testing__dispatch__names_for_edit__widen_to" "$__testing__dispatch__names_for_edit__remapped")" ;;
  esac
  @unlet __testing__dispatch__names_for_edit__ kind added_areas remapped widen_to
  @unique __testing__dispatch__names_for_edit__out "$__testing__dispatch__names_for_edit__names"
  println "$__testing__dispatch__names_for_edit__out"
}

:<<'FUN'
The names an additive edit selects for: the review's <names> with the
<added> areas joined in, logged as the reason the run selects.

  $1 names   $2 added areas
FUN
__testing__dispatch__names_additive() {
  log "testing/dispatch: $(__testing__dispatch__additive_line "$2") -- selecting as the review's labels ask."
  @concat __testing__dispatch__names_additive__out "$1" "$2"
  println "$__testing__dispatch__names_additive__out"
}

:<<'FUN'
The names a remapping that reaches areas selects for: the review's <names>
with the <added> areas and the areas the remapping <reaches> joined in,
logged with the <remapped> phrases as the reason the run selects.

  $1 names   $2 added areas   $3 the areas reached (widen_to)   $4 remapped phrases
FUN
__testing__dispatch__names_remapping() {
  log "testing/dispatch: $(__testing__dispatch__remapped_line "$4") -- selecting the remapped areas with the review's labels."
  @concat __testing__dispatch__names_remapping__names "$1" "$3"
  @concat __testing__dispatch__names_remapping__out "$__testing__dispatch__names_remapping__names" "$2"
  println "$__testing__dispatch__names_remapping__out"
}

:<<'FUN'
Prints the <plan> with the config edit it was reached through: config_edit
as the edit's <kind>, and remapped as the classifier's phrases when there are
any, so the record says which edit the run was classified or widened by.

  $1 plan   $2 kind (additive or remapping)   $3 remapped (struct array of phrases)
FUN
__testing__dispatch__with_config_edit() {
  @wrap __testing__dispatch__with_config_edit__wrap_47 "$2"
  @set __testing__dispatch__with_config_edit__plan "$1" '.config_edit' "$__testing__dispatch__with_config_edit__wrap_47"
  if @empty "$3"; then
    println "$__testing__dispatch__with_config_edit__plan"
    return 0
  fi
  @set __testing__dispatch__with_config_edit__out "$__testing__dispatch__with_config_edit__plan" '.remapped' "$3"
  println "$__testing__dispatch__with_config_edit__out"
}

:<<'FUN'
Prints the plan the review's labels and changed files select, once the config
itself is settled: the full suite when no area/* label is present, when a
changed file is one no selector claims, or when an impacted area is tagged
full_suite or is code no test speaks for; the net-new plan when the
unclaimed files are all added; otherwise the union of what the selectors
select. Every plan past the label check carries what each selector claimed
and contributed, so the record can attribute an escape to a tier.

  $1  The selection context ({names, changed, added, config, suites, dispatch,
      own}): the area names to select for, the review's changed and added
      files, the testing config, the effective suites, the dispatch flag, and
      whether the named areas' own tests alone are asked for
FUN
__testing__dispatch__plan_selection() {
  @let "$1" __testing__dispatch__plan_selection__ names changed added config suites dispatch own

  # No area/* labels on the review: run the full suite, never zero tests.
  @len __testing__dispatch__plan_selection__count "$__testing__dispatch__plan_selection__names"
  if @is_zero "$__testing__dispatch__plan_selection__count"; then
    __testing__dispatch__decide full_suite no_labels \
      "$__testing__dispatch__plan_selection__dispatch" \
      "no area/* labels on the review -- running the full suite for every runner." \
      full_suites \
      "$__testing__dispatch__plan_selection__suites"
    return 0
  fi

  __testing__dispatch__plan_selection__areas="$(areas__compute_areas \
    "$__testing__dispatch__plan_selection__config"
  )" || return 1

  # "new" is the reserved unmapped label, not a real area, so it is dropped.
  @arr __testing__dispatch__plan_selection__arr_48 new
  @difference __testing__dispatch__plan_selection__mapped \
    "$__testing__dispatch__plan_selection__names" \
    "$__testing__dispatch__plan_selection__arr_48"
  __testing__dispatch__plan_selection__picked="$(testing__pick_areas \
    "$__testing__dispatch__plan_selection__areas" \
    "$__testing__dispatch__plan_selection__mapped"
  )"

  # The impacted areas and every area that loads them, or the impacted ones
  # alone when their own tests are asked for, attached once here and handed
  # to the selectors, so the area selector reads them rather than deriving
  # them a second time.
  log "testing/dispatch: deriving test files for the impacted areas..."
  __testing__dispatch__plan_selection__attached="$(__testing__dispatch__attach_reached \
    "$__testing__dispatch__plan_selection__areas" \
    "$__testing__dispatch__plan_selection__mapped" \
    "$__testing__dispatch__plan_selection__suites" \
    "$__testing__dispatch__plan_selection__own"
  )" || return 1

  @obj __testing__dispatch__plan_selection__obj_49
  @get __testing__dispatch__plan_selection__get_50 "$__testing__dispatch__plan_selection__config" '.selectors' "$__testing__dispatch__plan_selection__obj_49"
  @obj __testing__dispatch__plan_selection__obj_51 \
      '.names' "$__testing__dispatch__plan_selection__mapped" \
      '.added' "$__testing__dispatch__plan_selection__added" \
      '.areas' "$__testing__dispatch__plan_selection__areas" \
      '.suites' "$__testing__dispatch__plan_selection__suites" \
      '.attached' "$__testing__dispatch__plan_selection__attached" \
      '.modes' "$__testing__dispatch__plan_selection__get_50"
  __testing__dispatch__plan_selection__selections="$(testing__selectors__selections \
    "$__testing__dispatch__plan_selection__changed" \
    "$__testing__dispatch__plan_selection__obj_51"
  )" || return 1

  @obj __testing__dispatch__plan_selection__obj_52 \
    '.names' "$__testing__dispatch__plan_selection__names" \
    '.mapped' "$__testing__dispatch__plan_selection__mapped" \
    '.changed' "$__testing__dispatch__plan_selection__changed" \
    '.added' "$__testing__dispatch__plan_selection__added" \
    '.areas' "$__testing__dispatch__plan_selection__areas" \
    '.picked' "$__testing__dispatch__plan_selection__picked" \
    '.attached' "$__testing__dispatch__plan_selection__attached" \
    '.suites' "$__testing__dispatch__plan_selection__suites" \
    '.dispatch' "$__testing__dispatch__plan_selection__dispatch" \
    '.selections' "$__testing__dispatch__plan_selection__selections" \
    '.own' "$__testing__dispatch__plan_selection__own"
  __testing__dispatch__plan_selection__plan="$(__testing__dispatch__plan_from_selections "$__testing__dispatch__plan_selection__obj_52")"
  __testing__dispatch__plan_selection__status=$?
  @unlet __testing__dispatch__plan_selection__ names changed added config suites dispatch own
  @is_zero "$__testing__dispatch__plan_selection__status" || return 1
  println "$__testing__dispatch__plan_selection__plan"
}

:<<'FUN'
Prints the plan the selectors' answers make: the files they left unclaimed
and the union of their tests handed to the claimed-file rules, and what each
selector claimed and contributed set on the plan as .selectors.

  $1  The selection context, with .selections (from
      testing__selectors__selections) beside what __testing__dispatch__plan_claimed reads
FUN
__testing__dispatch__plan_from_selections() {
  @get __testing__dispatch__plan_from_selections__selections "$1" '.selections'
  @get __testing__dispatch__plan_from_selections__changed "$1" '.changed'
  __testing__dispatch__plan_from_selections__unclaimed="$(testing__selectors__unclaimed \
    "$__testing__dispatch__plan_from_selections__selections" \
    "$__testing__dispatch__plan_from_selections__changed"
  )"
  __testing__dispatch__plan_from_selections__selected="$(testing__selectors__union \
    "$__testing__dispatch__plan_from_selections__selections" \
    "$__testing__dispatch__plan_from_selections__changed"
  )"

  @set __testing__dispatch__plan_from_selections__set_53 "$1" \
    '.unclaimed' "$__testing__dispatch__plan_from_selections__unclaimed" \
    '.selected' "$__testing__dispatch__plan_from_selections__selected"
  __testing__dispatch__plan_from_selections__plan="$(__testing__dispatch__plan_claimed "$__testing__dispatch__plan_from_selections__set_53")" || return 1

  @set __testing__dispatch__plan_from_selections__out "$__testing__dispatch__plan_from_selections__plan" \
    '.selectors' \
    "$(testing__selectors__attribution "$__testing__dispatch__plan_from_selections__selections")"
  println "$__testing__dispatch__plan_from_selections__out"
}

:<<'FUN'
The mapped areas and every area that loads one of them, or the mapped areas
alone when their own tests are asked for, with their tests attached: what
the widening rules read and what the area selector selects from. Fails when
the attach produced no map: a run on nothing would pass tests it never chose.

  $1 the flat area map   $2 the mapped area names   $3 effective suites
  $4 own (struct boolean)
FUN
__testing__dispatch__attach_reached() {
  __testing__dispatch__attach_reached__reached="$(__testing__dispatch__areas_to_attach "$1" "$2" "$4")" || return 1
  __testing__dispatch__attach_reached__picked="$(testing__pick_areas \
    "$1" \
    "$__testing__dispatch__attach_reached__reached"
  )"
  __testing__dispatch__attach_reached__attached="$(__testing__dispatch__attach_for_plan \
    "$__testing__dispatch__attach_reached__picked" \
    "$3" \
    "$4"
  )" || return 1

  # Emptiness checked apart from validity: jq 1.6's -e exits 0 on empty
  # input where 1.8 does not, and this guard cannot ride that difference.
  if ! @defined "$__testing__dispatch__attach_reached__attached" \
    || ! @is_valid "$__testing__dispatch__attach_reached__attached"; then
    fatal "testing/dispatch: resolving tests for areas $2 produced no selection. This run will be treated as failed to protect from running nothing and passing silently."
    return 1
  fi
  println "$__testing__dispatch__attach_reached__attached"
}

:<<'FUN'
Prints the plan once the selectors have answered: the full suite on a
changed file no selector claims that is not net-new (mapping drift, read
over every selector), or on an impacted area tagged full_suite; the net-new
plan when every unclaimed file is added; the full suite for area/new with
no net-new file; otherwise the impacted areas' plan over the union of what
the selectors selected.

  $1  The claimed context ({names, mapped, changed, added, unclaimed,
      selected, areas, picked, attached, suites, dispatch})
FUN
__testing__dispatch__plan_claimed() {
  @let "$1" __testing__dispatch__plan_claimed__ names mapped changed added unclaimed selected areas picked attached suites dispatch own

  __testing__dispatch__plan_claimed__drift="$(__testing__dispatch__has_drift \
    "$__testing__dispatch__plan_claimed__unclaimed" \
    "$__testing__dispatch__plan_claimed__added"
  )"
  if @is_true "$__testing__dispatch__plan_claimed__drift"; then
    __testing__dispatch__decide full_suite mapping_drift \
      "$__testing__dispatch__plan_claimed__dispatch" \
      "mapping drift -- running the full suite for every runner." \
      full_suites \
      "$__testing__dispatch__plan_claimed__suites"
    return 0
  fi

  if @is_true "$(__testing__dispatch__any_full_suite "$__testing__dispatch__plan_claimed__picked")"; then
    __testing__dispatch__plan_claimed__widened="$(testing__widened_by \
      "$__testing__dispatch__plan_claimed__areas" \
      "$__testing__dispatch__plan_claimed__picked" \
      "$__testing__dispatch__plan_claimed__changed"
    )" || return 1
    __testing__dispatch__plan_claimed__decision="$(__testing__dispatch__decide full_suite full_suite_area \
      "$__testing__dispatch__plan_claimed__dispatch" \
      "$(__testing__dispatch__widened_line "$__testing__dispatch__plan_claimed__widened") -- running the full suite for every runner." \
      full_suites \
      "$__testing__dispatch__plan_claimed__suites"
    )"
    @set __testing__dispatch__plan_claimed__out "$__testing__dispatch__plan_claimed__decision" \
      '.widened_by' \
      "$__testing__dispatch__plan_claimed__widened"
    println "$__testing__dispatch__plan_claimed__out"
    return 0
  fi

  if @len __testing__dispatch__plan_claimed__len_54 "$__testing__dispatch__plan_claimed__unclaimed"; [ "$__testing__dispatch__plan_claimed__len_54" -gt 0 ]; then
    __testing__dispatch__plan_net_new \
      "$__testing__dispatch__plan_claimed__changed" \
      "$__testing__dispatch__plan_claimed__added" \
      "$__testing__dispatch__plan_claimed__unclaimed" \
      "$__testing__dispatch__plan_claimed__selected" \
      "$__testing__dispatch__plan_claimed__suites" \
      "$__testing__dispatch__plan_claimed__dispatch"
    return 0
  fi

  if @arr __testing__dispatch__plan_claimed__arr_55 new; @intersect __testing__dispatch__plan_claimed__intersect_56 "$__testing__dispatch__plan_claimed__names" "$__testing__dispatch__plan_claimed__arr_55"; @len __testing__dispatch__plan_claimed__len_57 "$__testing__dispatch__plan_claimed__intersect_56"; [ "$__testing__dispatch__plan_claimed__len_57" -gt 0 ]; then
    __testing__dispatch__decide full_suite area_new_without_new_files \
      "$__testing__dispatch__plan_claimed__dispatch" \
      "area/new with no net-new files -- running the full suite for every runner." \
      full_suites \
      "$__testing__dispatch__plan_claimed__suites"
    return 0
  fi

  __testing__dispatch__plan_scoped \
    "$__testing__dispatch__plan_claimed__attached" \
    "$__testing__dispatch__plan_claimed__selected" \
    "$__testing__dispatch__plan_claimed__suites" \
    "$__testing__dispatch__plan_claimed__mapped" \
    "$__testing__dispatch__plan_claimed__dispatch" \
    "$__testing__dispatch__plan_claimed__own"
  __testing__dispatch__plan_claimed__status=$?
  @unlet __testing__dispatch__plan_claimed__ names mapped changed added unclaimed selected areas picked attached suites dispatch own
  return "$__testing__dispatch__plan_claimed__status"
}

:<<'FUN'
Prints the names of the areas whose tests attach for a selection: the
impacted areas and every area that loads them, so an importer outside the
labels still brings its tests; or, when the areas' own tests alone are asked
for, the impacted areas and nothing more.

  __testing__dispatch__areas_to_attach "$areas" '["lib.gitlab"]' false  ->  ["lib.forge","lib.gitlab","lib.releases",...]
  __testing__dispatch__areas_to_attach "$areas" '["lib.gitlab"]' true   ->  ["lib.gitlab"]

  $1 the flat area map   $2 impacted area names   $3 own (struct boolean)
FUN
__testing__dispatch__areas_to_attach() {
  if @is_true "$3"; then
    println "$2"
    return 0
  fi

  testing__with_importers "$1" "$2"
}


:<<'FUN'
Prints the plan for a review with net-new files: changed files no selector
claims that git reports as added. A purely net-new review plans only the
added files' own derived tests, alongside what the selectors selected for
any impacted area; a review that also edits code, or whose added files no
runner claims, plans the full suite (zero tests is never safe).

  $1 changed   $2 added   $3 unclaimed (all added here)
  $4 the tests the selectors selected   $5 effective suites   $6 dispatch
FUN
__testing__dispatch__plan_net_new() {
  if ! __testing__dispatch__pure_net_new "$1" "$2"; then
    __testing__dispatch__decide full_suite net_new_with_edits "$6" \
      "net-new files alongside edited code -- running the full suite for every runner." \
      full_suites \
      "$5"
    return 0
  fi

  __testing__dispatch__plan_net_new__testing_dispatch__net_new__derived="$(testing__derive_for_files "$3" "$5")"
  if @keys __testing__dispatch__plan_net_new__keys_58 "$__testing__dispatch__plan_net_new__testing_dispatch__net_new__derived"; @len __testing__dispatch__plan_net_new__len_59 "$__testing__dispatch__plan_net_new__keys_58"; [ "$__testing__dispatch__plan_net_new__len_59" -eq 0 ]; then
    __testing__dispatch__decide full_suite net_new_unclaimed "$6" \
      "net-new files no runner claims -- running the full suite for every runner." \
      full_suites \
      "$5"
    return 0
  fi

  __testing__dispatch__plan_net_new__testing_dispatch__net_new__selected="$(__testing__dispatch__merge_selected \
    "$4" \
    "$__testing__dispatch__plan_net_new__testing_dispatch__net_new__derived")"

  __testing__dispatch__decide selected net_new "$6" \
    "purely net-new review -- running the added files' own derived tests." \
    selected \
    "$5" \
    "$__testing__dispatch__plan_net_new__testing_dispatch__net_new__selected"
}

:<<'FUN'
Prints the plan for the impacted areas' tests: the full suite when any impacted
area is code no test speaks for, a clean no-op plan when the selectors
selected nothing, and the selected tests otherwise.

Those are not the same outcome. "No tests select for these areas" is a plan
only when every area says it has none to select: running nothing for a docs
change satisfies it. An area that is neither inert nor attached to any test
is a gap in the mapping, and running nothing for it would prove nothing, so
the run widens instead.

  $1 the attached areas (impacted ones and their importers, or the impacted
     ones alone when their own tests are asked for)
  $2 the tests the selectors selected   $3 effective suites
  $4 impacted area names   $5 dispatch
  $6 own (struct boolean, optional): the named areas' own tests alone were
     asked for
FUN
__testing__dispatch__plan_scoped() {
  # Only an impacted area with nothing to run is a gap; an importer attached
  # for its tests is not what the review changed.
  __testing__dispatch__plan_scoped__testing_dispatch__scoped__untested="$(testing__untested_areas \
    "$(testing__pick_areas "$1" "$4")")"
  if ! @empty "$__testing__dispatch__plan_scoped__testing_dispatch__scoped__untested"; then
    @join __testing__dispatch__plan_scoped__join_60 "$__testing__dispatch__plan_scoped__testing_dispatch__scoped__untested" ", "
    __testing__dispatch__decide full_suite untested_area "$5" \
      "untested area(s) $__testing__dispatch__plan_scoped__join_60 -- code no test speaks for; running the full suite for every runner." \
      full_suites \
      "$3"
    return 0
  fi

  if @keys __testing__dispatch__plan_scoped__keys_61 "$2"; @len __testing__dispatch__plan_scoped__len_62 "$__testing__dispatch__plan_scoped__keys_61"; [ "$__testing__dispatch__plan_scoped__len_62" -eq 0 ]; then
    __testing__dispatch__decide none no_impacted_tests "$5" \
      "no impacted tests for areas $4; nothing to run." \
      none \
      "$3"
    return 0
  fi
  @false __testing__dispatch__plan_scoped__false_63
  __testing__dispatch__decide selected impacted_areas "$5" \
    "$(__testing__dispatch__scoped_line "${6:-$__testing__dispatch__plan_scoped__false_63}")" \
    selected \
    "$3" \
    "$2"
}

:<<'FUN'
The attached areas for a scoped plan: every area's own tests alone when the
caller asked for them, its importers' tests joined in otherwise.

  $1 the areas to attach   $2 effective suites   $3 own (struct boolean)
FUN
__testing__dispatch__attach_for_plan() {
  if @is_true "$3"; then
    testing__attach_own_tests "$1" "$2"
    return
  fi

  testing__attach_tests "$1" "$2"
}

:<<'FUN'
The log line a scoped plan announces its decision with: what the run covers,
so a reader of the job log can tell a site's floor from a review's selection.

  __testing__dispatch__scoped_line false  ->  running the tests the impacted areas select.
  __testing__dispatch__scoped_line true   ->  running the named areas' own tests, none of their importers'.

  $1 own (struct boolean)
FUN
__testing__dispatch__scoped_line() {
  if @is_true "$1"; then
    printf "running the named areas' own tests, none of their importers'.\n"
    return 0
  fi

  printf 'running the tests the impacted areas select.\n'
}

:<<'FUN'
Runs the tests the plan names and prints the suite rows they produced.

Test output goes to fd 3 (the caller's stdout); this function's stdout is the
rows array. testing__run_impacted opens fd 3 before capturing the rows.

  $1 plan
FUN
__testing__dispatch__execute() {
  @let "$1" __testing__dispatch__execute__ run suites selected

  case "$__testing__dispatch__execute__run" in
    none|'') __testing__dispatch__observe_none "$__testing__dispatch__execute__suites" ;;
    all_frameworks) __testing__dispatch__observe_all_frameworks ;;
    full_suites) __testing__dispatch__observe_full_suites "$__testing__dispatch__execute__suites" ;;
    selected) __testing__dispatch__observe_selected \
      "$__testing__dispatch__execute__selected" \
      "$__testing__dispatch__execute__suites" ;;
    *) error "testing/dispatch: unknown run $__testing__dispatch__execute__run"; return 1 ;;
  esac
  __testing__dispatch__execute__status=$?
  @unlet __testing__dispatch__execute__ run suites selected
  return "$__testing__dispatch__execute__status"
}

:<<'FUN'
No suite runs, and every configured suite still gets the row of a suite that
ran nothing (selected 0, its escape key), so the escape check judges the run
like a narrowed one: a full-suite failure is a failure selection missed. A
plan naming no suites prints an empty rows array.

  $1 suites
FUN
__testing__dispatch__observe_none() {
  @obj __testing__dispatch__observe_none__obj_64
  @obj __testing__dispatch__observe_none__obj_65
  __testing__dispatch__observe_selected "$__testing__dispatch__observe_none__obj_64" "${1:-$__testing__dispatch__observe_none__obj_65}"
}

:<<'FUN'
Appends a suite row to the accumulator when the helper printed one.

  $1 rows   $2 row or ""
FUN
__testing__dispatch__absorb_row() {
  if ! @defined "$2"; then
    println "$1"
    return 0
  fi
  @push __testing__dispatch__absorb_row__out "$1" "$2"
  println "$__testing__dispatch__absorb_row__out"
}

:<<'FUN'
Runs a suite through its runner. When $1 is "collect", test output goes to
fd 3 so the caller can capture the suite row on stdout.

  $1 collect or ""   $2 runner   $3 suite config   remaining files
FUN
__testing__dispatch__invoke_runner() {
  __testing__dispatch__invoke_runner__collect="$1"
  __testing__dispatch__invoke_runner__runner="$2"
  __testing__dispatch__invoke_runner__cfg="$3"
  shift 3
  case "$__testing__dispatch__invoke_runner__collect" in
    collect)
      testing__run \
        "$__testing__dispatch__invoke_runner__runner" \
        "$__testing__dispatch__invoke_runner__cfg" \
        "$@" \
        >&3
      ;;
    *)
      testing__run \
        "$__testing__dispatch__invoke_runner__runner" \
        "$__testing__dispatch__invoke_runner__cfg" \
        "$@"
      ;;
  esac
}

:<<'FUN'
Prints the suite row when collecting; prints nothing otherwise.

  $1 collect or ""   remaining args are testing__metrics__suite_row's
FUN
__testing__dispatch__note_row() {
  if [ "$1" != collect ]; then
    return 0
  fi
  shift
  testing__metrics__suite_row "$@"
}

:<<'FUN'
Runs every registered framework in full and prints the suite rows.

Usage: __testing__dispatch__observe_all_frameworks
FUN
__testing__dispatch__observe_all_frameworks() {
  __testing__dispatch__observe_all_frameworks__ids="$(testing__adapter_ids)"
  @len __testing__dispatch__observe_all_frameworks__count \
    "$__testing__dispatch__observe_all_frameworks__ids"
  __testing__dispatch__observe_all_frameworks__i=0
  __testing__dispatch__observe_all_frameworks__failed=0
  @arr __testing__dispatch__observe_all_frameworks__rows

  while [ "$__testing__dispatch__observe_all_frameworks__i" -lt \
    "$__testing__dispatch__observe_all_frameworks__count" ]; do
    @get __testing__dispatch__observe_all_frameworks__id \
      "$__testing__dispatch__observe_all_frameworks__ids" \
      ".[$__testing__dispatch__observe_all_frameworks__i]"
    __testing__dispatch__observe_all_frameworks__i=$((__testing__dispatch__observe_all_frameworks__i + 1))

    __testing__dispatch__observe_all_frameworks__row="$(__testing__dispatch__run_framework_in_full \
      "$__testing__dispatch__observe_all_frameworks__id" \
      collect
    )" || __testing__dispatch__observe_all_frameworks__failed=1

    __testing__dispatch__observe_all_frameworks__rows="$(__testing__dispatch__absorb_row \
      "$__testing__dispatch__observe_all_frameworks__rows" \
      "$__testing__dispatch__observe_all_frameworks__row"
    )"
  done

  println "$__testing__dispatch__observe_all_frameworks__rows"
  return "$__testing__dispatch__observe_all_frameworks__failed"
}

:<<'FUN'
Runs every configured suite in full and prints the suite rows.

  $1 suites
FUN
__testing__dispatch__observe_full_suites() {
  @keys __testing__dispatch__observe_full_suites__names "$1"
  @len __testing__dispatch__observe_full_suites__count \
    "$__testing__dispatch__observe_full_suites__names"
  __testing__dispatch__observe_full_suites__i=0
  __testing__dispatch__observe_full_suites__failed=0
  @arr __testing__dispatch__observe_full_suites__rows

  while [ "$__testing__dispatch__observe_full_suites__i" -lt \
    "$__testing__dispatch__observe_full_suites__count" ]; do
    @get __testing__dispatch__observe_full_suites__suite \
      "$__testing__dispatch__observe_full_suites__names" \
      ".[$__testing__dispatch__observe_full_suites__i]"
    __testing__dispatch__observe_full_suites__i=$((__testing__dispatch__observe_full_suites__i + 1))

    @get __testing__dispatch__observe_full_suites__get_66 "$1" ".\"$__testing__dispatch__observe_full_suites__suite\""
    __testing__dispatch__observe_full_suites__row="$(__testing__dispatch__run_suite_in_full \
      "$__testing__dispatch__observe_full_suites__suite" \
      "$__testing__dispatch__observe_full_suites__get_66" \
      collect
    )" || __testing__dispatch__observe_full_suites__failed=1

    __testing__dispatch__observe_full_suites__rows="$(__testing__dispatch__absorb_row \
      "$__testing__dispatch__observe_full_suites__rows" \
      "$__testing__dispatch__observe_full_suites__row"
    )"
  done

  println "$__testing__dispatch__observe_full_suites__rows"
  return "$__testing__dispatch__observe_full_suites__failed"
}

:<<'FUN'
Runs a suite-keyed selection and prints the suite rows. Every suite the config
names gets a row: one selection skipped records that it ran nothing, so an
escape check can tell a suite left out from a suite that ran everything.

  $1 selected   $2 suites
FUN
__testing__dispatch__observe_selected() {
  @keys __testing__dispatch__observe_selected__names "$2"
  @len __testing__dispatch__observe_selected__count \
    "$__testing__dispatch__observe_selected__names"
  __testing__dispatch__observe_selected__i=0
  __testing__dispatch__observe_selected__failed=0
  @arr __testing__dispatch__observe_selected__rows

  while [ "$__testing__dispatch__observe_selected__i" -lt \
    "$__testing__dispatch__observe_selected__count" ]; do
    @get __testing__dispatch__observe_selected__suite \
      "$__testing__dispatch__observe_selected__names" \
      ".[$__testing__dispatch__observe_selected__i]"
    __testing__dispatch__observe_selected__i=$((__testing__dispatch__observe_selected__i + 1))

    @arr __testing__dispatch__observe_selected__arr_67
    @get __testing__dispatch__observe_selected__get_68 "$1" ".\"$__testing__dispatch__observe_selected__suite\"" "$__testing__dispatch__observe_selected__arr_67"
    __testing__dispatch__observe_selected__row="$(__testing__dispatch__run_suite \
      "$__testing__dispatch__observe_selected__suite" \
      "$__testing__dispatch__observe_selected__get_68" \
      "$2" \
      collect
    )" || __testing__dispatch__observe_selected__failed=1

    __testing__dispatch__observe_selected__rows="$(__testing__dispatch__absorb_row \
      "$__testing__dispatch__observe_selected__rows" \
      "$__testing__dispatch__observe_selected__row"
    )"
  done

  println "$__testing__dispatch__observe_selected__rows"
  return "$__testing__dispatch__observe_selected__failed"
}

:<<'FUN'
Unions two suite-keyed selection maps into one, per suite and de-duplicated.

  $1 selection map   $2 other selection map
FUN
__testing__dispatch__merge_selected() {
  @run_awk __testing__dispatch__merge_selected__out "$__testing__dispatch__MERGE_SELECTED" "$1" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" \
    --with "$2" || return 1
  println "$__testing__dispatch__merge_selected__out"
}

:<<'PUB_FUN'
Runs every configured suite in full via its runner's run_all role -- the
fail-safe path for area/new. testing__run with no files invokes <runner>_run_all
(bats runs all of test/; cargo runs the whole workspace), so this never depends
on the per-area mapping being complete.

  suites  {"<suite>": {"runner": <id>, ...}, ...}  the areas `suites` config

Every suite is attempted; returns 1 if any runner is unregistered or its run
fails, 0 only when all succeed.

Usage: testing__run_full_suites "$suites"
PUB_FUN
testing__run_full_suites() {
  @keys __testing__run_full_suites__testing_dispatch__full__names "$1"
  @len __testing__run_full_suites__testing_dispatch__full__count "$__testing__run_full_suites__testing_dispatch__full__names"
  __testing__run_full_suites__testing_dispatch__full__i=0
  __testing__run_full_suites__testing_dispatch__full__failed=0

  while [ "$__testing__run_full_suites__testing_dispatch__full__i" -lt "$__testing__run_full_suites__testing_dispatch__full__count" ]; do
    @get __testing__run_full_suites__testing_dispatch__full__suite "$__testing__run_full_suites__testing_dispatch__full__names" ".[$__testing__run_full_suites__testing_dispatch__full__i]"
    __testing__run_full_suites__testing_dispatch__full__i=$((__testing__run_full_suites__testing_dispatch__full__i + 1))

    if @get __testing__run_full_suites__get_69 "$1" ".\"$__testing__run_full_suites__testing_dispatch__full__suite\""; ! __testing__dispatch__run_suite_in_full \
      "$__testing__run_full_suites__testing_dispatch__full__suite" \
      "$__testing__run_full_suites__get_69"; then
      __testing__run_full_suites__testing_dispatch__full__failed=1
    fi
  done

  return "$__testing__run_full_suites__testing_dispatch__full__failed"
}

:<<'FUN'
Runs one suite in full through its runner. Returns 0 on success, 1 on a missing
runner or a failing run.

A full-suite run selected every test the suite has, so its selected count is its
total and there is no file list worth recording.

When $3 is "collect", test output goes to fd 3 and the suite row is printed.

  $1 suite   $2 suite config   $3 collect (optional)
FUN
__testing__dispatch__run_suite_in_full() {
  __testing__dispatch__run_suite_in_full__testing_dispatch__in_full__suite="$1"
  __testing__dispatch__run_suite_in_full__testing_dispatch__in_full__cfg="$2"
  __testing__dispatch__run_suite_in_full__testing_dispatch__in_full__collect="${3:-}"
  @get __testing__dispatch__run_suite_in_full__testing_dispatch__in_full__runner "$2" '.runner' "$1"

  if @is_false "$(testing__adapter_registered "$__testing__dispatch__run_suite_in_full__testing_dispatch__in_full__runner")"; then
    error "testing/dispatch: suite '$1' needs runner '$__testing__dispatch__run_suite_in_full__testing_dispatch__in_full__runner', which is not registered."
    return 1
  fi

  if @is_true "$(testing__shard__is_partial)"; then
    __testing__dispatch__run_suite_in_full_shard \
      "$1" \
      "$2" \
      "$__testing__dispatch__run_suite_in_full__testing_dispatch__in_full__collect" \
      "$__testing__dispatch__run_suite_in_full__testing_dispatch__in_full__runner"
    return
  fi

  log "testing/dispatch: running full suite '$1' via runner '$__testing__dispatch__run_suite_in_full__testing_dispatch__in_full__runner'."
  __testing__dispatch__run_suite_in_full__testing_dispatch__in_full__total="$(testing__metrics__suite_total "$2")"
  __testing__dispatch__run_suite_in_full__testing_dispatch__in_full__started="$(time__epoch_seconds)"
  __testing__dispatch__run_suite_in_full__testing_dispatch__in_full__failed=0
  __testing__dispatch__invoke_runner \
    "$__testing__dispatch__run_suite_in_full__testing_dispatch__in_full__collect" \
    "$__testing__dispatch__run_suite_in_full__testing_dispatch__in_full__runner" \
    "$__testing__dispatch__run_suite_in_full__testing_dispatch__in_full__cfg" \
    || __testing__dispatch__run_suite_in_full__testing_dispatch__in_full__failed=1
  __testing__dispatch__note_row \
    "$__testing__dispatch__run_suite_in_full__testing_dispatch__in_full__collect" \
    "$__testing__dispatch__run_suite_in_full__testing_dispatch__in_full__suite" \
    "$__testing__dispatch__run_suite_in_full__testing_dispatch__in_full__runner" \
    "$__testing__dispatch__run_suite_in_full__testing_dispatch__in_full__total" \
    "$__testing__dispatch__run_suite_in_full__testing_dispatch__in_full__total" \
    "$__testing__dispatch__run_suite_in_full__testing_dispatch__in_full__started" \
    "$(__testing__dispatch__status_word "$__testing__dispatch__run_suite_in_full__testing_dispatch__in_full__failed")" \
    ""

  return "$__testing__dispatch__run_suite_in_full__testing_dispatch__in_full__failed"
}

:<<'FUN'
Runs this job's shard of a suite in full, when the job is one of several
parallel jobs. The suite's files are dealt to the shards as
lib/testing/shard.sh describes and this shard's share goes to the runner's
run_selected role, so the shards together run the suite once and each
records the share it ran. A shard dealt no file runs nothing and records
that. A suite with no file layout cannot be dealt, so the first shard runs
it in full and the other shards leave it, recording a row that counts
nothing.

  $1 suite   $2 suite config   $3 collect or ""   $4 runner
FUN
__testing__dispatch__run_suite_in_full_shard() {
  __testing__dispatch__run_suite_in_full_shard__suite="$1"
  __testing__dispatch__run_suite_in_full_shard__cfg="$2"
  __testing__dispatch__run_suite_in_full_shard__collect="$3"
  __testing__dispatch__run_suite_in_full_shard__runner="$4"

  @get __testing__dispatch__run_suite_in_full_shard__root "$2" '.root' ''
  if ! @defined "$__testing__dispatch__run_suite_in_full_shard__root"; then
    __testing__dispatch__run_undealt_suite "$@"
    return
  fi

  __testing__dispatch__run_suite_in_full_shard__all="$(testing__metrics__suite_files "$2")"
  @len __testing__dispatch__run_suite_in_full_shard__total "$__testing__dispatch__run_suite_in_full_shard__all"
  __testing__dispatch__run_suite_in_full_shard__files="$(__testing__dispatch__dealt_files \
    "$__testing__dispatch__run_suite_in_full_shard__all"
  )"
  @len __testing__dispatch__run_suite_in_full_shard__count "$__testing__dispatch__run_suite_in_full_shard__files"
  log "testing/dispatch: running full suite '$1' via runner '$4', shard $(testing__shard__label): $__testing__dispatch__run_suite_in_full_shard__count of $__testing__dispatch__run_suite_in_full_shard__total file(s)."

  __testing__dispatch__run_suite_in_full_shard__i=0
  set --
  while [ "$__testing__dispatch__run_suite_in_full_shard__i" -lt "$__testing__dispatch__run_suite_in_full_shard__count" ]; do
    @get __testing__dispatch__run_suite_in_full_shard__file "$__testing__dispatch__run_suite_in_full_shard__files" ".[$__testing__dispatch__run_suite_in_full_shard__i]"
    set -- "$@" "$__testing__dispatch__run_suite_in_full_shard__file"
    __testing__dispatch__run_suite_in_full_shard__i=$((__testing__dispatch__run_suite_in_full_shard__i + 1))
  done

  __testing__dispatch__run_suite_in_full_shard__started="$(time__epoch_seconds)"
  __testing__dispatch__run_suite_in_full_shard__failed=0
  if [ "$#" -gt 0 ]; then
    __testing__dispatch__invoke_runner \
      "$__testing__dispatch__run_suite_in_full_shard__collect" \
      "$__testing__dispatch__run_suite_in_full_shard__runner" \
      "$__testing__dispatch__run_suite_in_full_shard__cfg" \
      "$@" \
      || __testing__dispatch__run_suite_in_full_shard__failed=1
  fi
  __testing__dispatch__note_row \
    "$__testing__dispatch__run_suite_in_full_shard__collect" \
    "$__testing__dispatch__run_suite_in_full_shard__suite" \
    "$__testing__dispatch__run_suite_in_full_shard__runner" \
    "$__testing__dispatch__run_suite_in_full_shard__count" \
    "$__testing__dispatch__run_suite_in_full_shard__total" \
    "$__testing__dispatch__run_suite_in_full_shard__started" \
    "$(__testing__dispatch__status_word "$__testing__dispatch__run_suite_in_full_shard__failed")" \
    ""

  return "$__testing__dispatch__run_suite_in_full_shard__failed"
}

:<<'FUN'
Runs a suite that cannot be dealt, since it has no file layout, on the first
shard only: that shard runs it in full through run_all and records it as an
undealt run does; every other shard leaves it and records a row that counts
nothing, so the fold still shows the suite once.

  $1 suite   $2 suite config   $3 collect or ""   $4 runner
FUN
__testing__dispatch__run_undealt_suite() {
  @get __testing__dispatch__run_undealt_suite__index "$(testing__shard)" '.index'
  if [ "$__testing__dispatch__run_undealt_suite__index" -ne 1 ]; then
    log "testing/dispatch: suite '$1' has no file layout to deal to the shards; shard 1 runs it, this one leaves it."
    __testing__dispatch__note_row \
      "$3" \
      "$1" \
      "$4" \
      "" \
      "" \
      "$(time__epoch_seconds)" \
      passed \
      ""
    return 0
  fi

  log "testing/dispatch: running full suite '$1' via runner '$4'; it has no file layout to deal to the shards, so this shard runs all of it."
  __testing__dispatch__run_undealt_suite__started="$(time__epoch_seconds)"
  __testing__dispatch__run_undealt_suite__failed=0
  __testing__dispatch__invoke_runner "$3" "$4" "$2" \
    || __testing__dispatch__run_undealt_suite__failed=1
  __testing__dispatch__note_row \
    "$3" \
    "$1" \
    "$4" \
    "" \
    "" \
    "$__testing__dispatch__run_undealt_suite__started" \
    "$(__testing__dispatch__status_word "$__testing__dispatch__run_undealt_suite__failed")" \
    ""
  return "$__testing__dispatch__run_undealt_suite__failed"
}

:<<'FUN'
The files of <files> that this job's shard runs, as a struct array: every
file when the job is one job, this shard's share when it is one of several.

  $1 files (struct array)
FUN
__testing__dispatch__dealt_files() {
  @join __testing__dispatch__dealt_files__lines "$1" "$__testing__dispatch__NL"
  __testing__dispatch__dealt_files__dealt="$(testing__shard__files "$__testing__dispatch__dealt_files__lines")"
  if ! @defined "$__testing__dispatch__dealt_files__dealt"; then
    @arr __testing__dispatch__dealt_files__out
    println "$__testing__dispatch__dealt_files__out"
    return 0
  fi
  @split __testing__dispatch__dealt_files__out "$__testing__dispatch__dealt_files__dealt"
  println "$__testing__dispatch__dealt_files__out"
}

:<<'FUN'
The row with the count of tests the run's JUnit report marked flaky -- failed,
then passed on a retry -- when the runner names a report and the run left
one; the row unchanged otherwise. A flaky test passed, so the run did, and the
count is what keeps the flake visible.

  $1 suite row   $2 runner   $3 suite config
FUN
__testing__dispatch__with_flaky_count() {
  __testing__dispatch__with_flaky_count__testing_dispatch__flaky__junit="$(testing__runner_junit_path "$2" "$3")"
  if ! @defined "$__testing__dispatch__with_flaky_count__testing_dispatch__flaky__junit" || [ ! -f "$__testing__dispatch__with_flaky_count__testing_dispatch__flaky__junit" ]; then
    println "$1"
    return 0
  fi

  __testing__dispatch__with_flaky_count__testing_dispatch__flaky__tests="$(testing__escapes_flaky_tests "$(dirname "$__testing__dispatch__with_flaky_count__testing_dispatch__flaky__junit")")"
  @len __testing__dispatch__with_flaky_count__len_70 "$__testing__dispatch__with_flaky_count__testing_dispatch__flaky__tests"
  @set __testing__dispatch__with_flaky_count__out "$1" '.flaky' "$__testing__dispatch__with_flaky_count__len_70"
  println "$__testing__dispatch__with_flaky_count__out"
}

:<<'PUB_FUN'
Runs one configured suite through its runner, by the name the testing config
gives it: in full, the way a dedicated full-suite job does, or narrowed to
the given test files, as a traced run does one file at a time. The suite's
runner sees the files it is handed or every test it has, and its report
lands wherever that runner leaves one. Writes no metrics record, since one
suite is not the full run the rollout baseline measures. Fails when the
repo has no testing config, the config does not validate, or no suite has
the name.

Usage: testing__run_suite "<suite>" [file...]
PUB_FUN
testing__run_suite() {
  __testing__run_suite__name="$1"
  shift
  __testing__run_suite__cfg="$(__testing__dispatch__suite_config "$__testing__run_suite__name")" || return 1

  if @is_zero "$#"; then
    __testing__dispatch__run_suite_in_full "$__testing__run_suite__name" "$__testing__run_suite__cfg"
    return
  fi

  @get __testing__run_suite__runner "$__testing__run_suite__cfg" '.runner' "$__testing__run_suite__name"
  log "testing/dispatch: running suite '$__testing__run_suite__name' via runner '$__testing__run_suite__runner' ($# file(s))."
  testing__run "$__testing__run_suite__runner" "$__testing__run_suite__cfg" "$@"
}

:<<'FUN'
The effective config of the suite the testing config names, or a failure
naming what is wrong: no config, one that does not validate, or no suite of
that name.

  $1 suite name
FUN
__testing__dispatch__suite_config() {
  __testing__dispatch__suite_config__config="$(areas__load_areas_config)"
  if ! @defined "$__testing__dispatch__suite_config__config"; then
    error "testing/dispatch: no testing config; there is no suite '$1' to run."
    return 1
  fi

  @obj __testing__dispatch__suite_config__obj_71
  @get __testing__dispatch__suite_config__suites "$__testing__dispatch__suite_config__config" '.suites' "$__testing__dispatch__suite_config__obj_71"
  if ! testing__validate_suites "$__testing__dispatch__suite_config__suites"; then
    error "testing/dispatch: invalid testing.suites config (see schema errors above)."
    return 1
  fi
  __testing__dispatch__suite_config__suites="$(testing__effective_suites "$__testing__dispatch__suite_config__suites")"

  @get __testing__dispatch__suite_config__cfg "$__testing__dispatch__suite_config__suites" ".\"$1\"" ''
  if ! @defined "$__testing__dispatch__suite_config__cfg"; then
    @keys __testing__dispatch__suite_config__keys_72 "$__testing__dispatch__suite_config__suites"
    @join __testing__dispatch__suite_config__join_73 "$__testing__dispatch__suite_config__keys_72" ", "
    error "testing/dispatch: no suite '$1' in the testing config (suites: $__testing__dispatch__suite_config__join_73)."
    return 1
  fi
  println "$__testing__dispatch__suite_config__cfg"
}

:<<'PUB_FUN'
Runs every registered framework's full suite -- the full-suite path for a repo
with no testing config, where there are no configured suites to scope to. Only
the adapters the repo imported are registered, so it runs exactly the repo's
frameworks, never another project's.

Every framework is attempted; returns 1 if any run fails, 0 when all succeed or
none is registered.

Usage: testing__run_all_frameworks
PUB_FUN
testing__run_all_frameworks() {
  __testing__run_all_frameworks__testing_dispatch__all_frameworks__ids="$(testing__adapter_ids)"
  @len __testing__run_all_frameworks__testing_dispatch__all_frameworks__count "$__testing__run_all_frameworks__testing_dispatch__all_frameworks__ids"
  __testing__run_all_frameworks__testing_dispatch__all_frameworks__i=0
  __testing__run_all_frameworks__testing_dispatch__all_frameworks__failed=0

  while [ "$__testing__run_all_frameworks__testing_dispatch__all_frameworks__i" -lt "$__testing__run_all_frameworks__testing_dispatch__all_frameworks__count" ]; do
    @get __testing__run_all_frameworks__testing_dispatch__all_frameworks__id "$__testing__run_all_frameworks__testing_dispatch__all_frameworks__ids" ".[$__testing__run_all_frameworks__testing_dispatch__all_frameworks__i]"
    __testing__run_all_frameworks__testing_dispatch__all_frameworks__i=$((__testing__run_all_frameworks__testing_dispatch__all_frameworks__i + 1))

    if ! __testing__dispatch__run_framework_in_full "$__testing__run_all_frameworks__testing_dispatch__all_frameworks__id"; then
      __testing__run_all_frameworks__testing_dispatch__all_frameworks__failed=1
    fi
  done

  return "$__testing__run_all_frameworks__testing_dispatch__all_frameworks__failed"
}

:<<'FUN'
Runs one registered framework's full suite on its own defaults. The framework
stands in for the suite name here: with no testing config there are no suite
names to use.

When $2 is "collect", test output goes to fd 3 and the suite row is printed.

  $1 runner id   $2 collect (optional)
FUN
__testing__dispatch__run_framework_in_full() {
  __testing__dispatch__run_framework_in_full__testing_dispatch__in_framework__cfg="$(testing__suite_defaults "$1")"
  __testing__dispatch__run_suite_in_full \
    "$1" \
    "$__testing__dispatch__run_framework_in_full__testing_dispatch__in_framework__cfg" \
    "${2:-}"
}

:<<'PUB_FUN'
Dispatches a suite-keyed selection of test files to the runners that execute them.

  selected  {"<suite>": [<file>, ...], ...}  e.g. from testing__tests_for_areas
  suites    {"<suite>": {"runner": <id>, ...}, ...}  the areas `suites` config

Each suite is routed to its runner (suites.<suite>.runner, defaulting to the
suite key) and run via testing__run with the suite's files as positional
arguments. Every suite is attempted; the function returns 1 if any suite failed
(an unregistered runner counts as a failure) and 0 only when all succeeded.

Usage: testing__dispatch_selected "$selected" "$suites"
PUB_FUN
testing__dispatch_selected() {
  __testing__dispatch_selected__testing_dispatch__selected__suites="$2"
  @keys __testing__dispatch_selected__testing_dispatch__selected__names "$1"
  @len __testing__dispatch_selected__testing_dispatch__selected__count "$__testing__dispatch_selected__testing_dispatch__selected__names"
  __testing__dispatch_selected__testing_dispatch__selected__i=0
  __testing__dispatch_selected__testing_dispatch__selected__failed=0

  while [ "$__testing__dispatch_selected__testing_dispatch__selected__i" -lt "$__testing__dispatch_selected__testing_dispatch__selected__count" ]; do
    @get __testing__dispatch_selected__testing_dispatch__selected__suite "$__testing__dispatch_selected__testing_dispatch__selected__names" ".[$__testing__dispatch_selected__testing_dispatch__selected__i]"
    __testing__dispatch_selected__testing_dispatch__selected__i=$((__testing__dispatch_selected__testing_dispatch__selected__i + 1))

    if @arr __testing__dispatch_selected__arr_74; @get __testing__dispatch_selected__get_75 "$1" ".\"$__testing__dispatch_selected__testing_dispatch__selected__suite\"" "$__testing__dispatch_selected__arr_74"; ! __testing__dispatch__run_suite \
      "$__testing__dispatch_selected__testing_dispatch__selected__suite" \
      "$__testing__dispatch_selected__get_75" \
      "$__testing__dispatch_selected__testing_dispatch__selected__suites"; then
      __testing__dispatch_selected__testing_dispatch__selected__failed=1
    fi
  done

  return "$__testing__dispatch_selected__testing_dispatch__selected__failed"
}

:<<'FUN'
Runs one suite's files through its runner. Returns 0 on success (or when the
suite has no files), 1 on a missing runner or a failing run. A job that is
one of several parallel jobs runs this shard's share of the files, as
lib/testing/shard.sh deals them, and records that share; the shards together
run the selection once.

When $4 is "collect", test output goes to fd 3 and the suite row is printed.

  $1 suite   $2 files (struct array)   $3 suites config   $4 collect (optional)
FUN
__testing__dispatch__run_suite() {
  __testing__dispatch__run_suite__suite="$1"
  __testing__dispatch__run_suite__files="$(__testing__dispatch__dealt_files "$2")"
  __testing__dispatch__run_suite__collect="${4:-}"
  @len __testing__dispatch__run_suite__count "$__testing__dispatch__run_suite__files"
  @get __testing__dispatch__run_suite__runner "$3" \
    ".\"$__testing__dispatch__run_suite__suite\".runner" "$__testing__dispatch__run_suite__suite"
  @obj __testing__dispatch__run_suite__obj_76
  @get __testing__dispatch__run_suite__cfg "$3" \
    ".\"$__testing__dispatch__run_suite__suite\"" "$__testing__dispatch__run_suite__obj_76"

  if [ "$__testing__dispatch__run_suite__count" -eq 0 ]; then
    log "testing/dispatch: suite '$__testing__dispatch__run_suite__suite' has no selected tests; skipping."
    __testing__dispatch__note_skipped_row \
      "$__testing__dispatch__run_suite__collect" \
      "$__testing__dispatch__run_suite__suite" \
      "$__testing__dispatch__run_suite__runner" \
      "$__testing__dispatch__run_suite__cfg"
    return 0
  fi

  if @is_false "$(testing__adapter_registered "$__testing__dispatch__run_suite__runner")"; then
    error "testing/dispatch: suite '$__testing__dispatch__run_suite__suite' needs runner '$__testing__dispatch__run_suite__runner', which is not registered."
    return 1
  fi

  __testing__dispatch__run_suite__i=0
  set --
  while [ "$__testing__dispatch__run_suite__i" -lt "$__testing__dispatch__run_suite__count" ]; do
    @get __testing__dispatch__run_suite__get_77 "$__testing__dispatch__run_suite__files" ".[$__testing__dispatch__run_suite__i]"
    set -- "$@" "$__testing__dispatch__run_suite__get_77"
    __testing__dispatch__run_suite__i=$((__testing__dispatch__run_suite__i + 1))
  done

  log "testing/dispatch: running suite '$__testing__dispatch__run_suite__suite' via runner '$__testing__dispatch__run_suite__runner' ($__testing__dispatch__run_suite__count file(s))."
  __testing__dispatch__run_suite__total="$(testing__metrics__suite_total "$__testing__dispatch__run_suite__cfg")"
  __testing__dispatch__run_suite__started="$(time__epoch_seconds)"
  __testing__dispatch__run_suite__failed=0
  __testing__dispatch__invoke_runner \
    "$__testing__dispatch__run_suite__collect" \
    "$__testing__dispatch__run_suite__runner" \
    "$__testing__dispatch__run_suite__cfg" \
    "$@" \
    || __testing__dispatch__run_suite__failed=1
  __testing__dispatch__run_suite__row="$(__testing__dispatch__note_row \
    "$__testing__dispatch__run_suite__collect" \
    "$__testing__dispatch__run_suite__suite" \
    "$__testing__dispatch__run_suite__runner" \
    "$__testing__dispatch__run_suite__count" \
    "$__testing__dispatch__run_suite__total" \
    "$__testing__dispatch__run_suite__started" \
    "$(__testing__dispatch__status_word "$__testing__dispatch__run_suite__failed")" \
    "$__testing__dispatch__run_suite__files"
  )"
  __testing__dispatch__note_joined_row \
    "$__testing__dispatch__run_suite__collect" \
    "$__testing__dispatch__run_suite__row" \
    "$__testing__dispatch__run_suite__runner" \
    "$__testing__dispatch__run_suite__cfg" \
    "$@"

  return "$__testing__dispatch__run_suite__failed"
}

:<<'FUN'
Prints the row of a suite selection skipped when collecting; prints nothing
otherwise. The row says the suite ran nothing: selected 0, an empty file list,
and the runner's escape key, so an escape check reads every failure the suite
had as an escape.

  $1 collect or ""   $2 suite   $3 runner   $4 suite config
FUN
__testing__dispatch__note_skipped_row() {
  if [ "$1" != collect ]; then
    return 0
  fi

  @arr __testing__dispatch__note_skipped_row__arr_78
  __testing__dispatch__note_skipped_row__testing_dispatch__skipped_row__row="$(testing__metrics__suite_row \
    "$2" \
    "$3" \
    0 \
    "$(testing__metrics__suite_total "$4")" \
    "$(time__epoch_seconds)" \
    passed \
    "$__testing__dispatch__note_skipped_row__arr_78"
  )"
  @set __testing__dispatch__note_skipped_row__out "$__testing__dispatch__note_skipped_row__testing_dispatch__skipped_row__row" '.escape_key' "$(testing__runner_escape_key "$3" "$4")"
  println "$__testing__dispatch__note_skipped_row__out"
}

:<<'FUN'
Prints a narrowed run's row with the escape join's fields added when
collecting; prints nothing otherwise. Every row names the runner's escape key
and, when the run left a JUnit report, counts the tests it marked flaky; a
package-keyed row also carries the packages the files narrowed the run to,
left off when the runner ran the whole workspace instead.

  $1 collect or ""   $2 suite row   $3 runner   $4 suite config   remaining files
FUN
__testing__dispatch__note_joined_row() {
  if [ "$1" != collect ]; then
    return 0
  fi
  __testing__dispatch__note_joined_row__testing_dispatch__joined_row__row="$2"
  __testing__dispatch__note_joined_row__testing_dispatch__joined_row__runner="$3"
  __testing__dispatch__note_joined_row__testing_dispatch__joined_row__cfg="$4"
  shift 4

  __testing__dispatch__note_joined_row__testing_dispatch__joined_row__key="$(testing__runner_escape_key \
    "$__testing__dispatch__note_joined_row__testing_dispatch__joined_row__runner" \
    "$__testing__dispatch__note_joined_row__testing_dispatch__joined_row__cfg")"
  @set __testing__dispatch__note_joined_row__testing_dispatch__joined_row__row "$__testing__dispatch__note_joined_row__testing_dispatch__joined_row__row" \
    '.escape_key' "$__testing__dispatch__note_joined_row__testing_dispatch__joined_row__key"
  __testing__dispatch__note_joined_row__testing_dispatch__joined_row__row="$(__testing__dispatch__with_flaky_count \
    "$__testing__dispatch__note_joined_row__testing_dispatch__joined_row__row" \
    "$__testing__dispatch__note_joined_row__testing_dispatch__joined_row__runner" \
    "$__testing__dispatch__note_joined_row__testing_dispatch__joined_row__cfg")"
  if [ "$__testing__dispatch__note_joined_row__testing_dispatch__joined_row__key" != package ]; then
    println "$__testing__dispatch__note_joined_row__testing_dispatch__joined_row__row"
    return 0
  fi

  __testing__dispatch__note_joined_row__testing_dispatch__joined_row__packages="$(testing__runner_selected_packages \
    "$__testing__dispatch__note_joined_row__testing_dispatch__joined_row__runner" \
    "$__testing__dispatch__note_joined_row__testing_dispatch__joined_row__cfg" \
    "$@"
  )" || return 1
  if @empty "$__testing__dispatch__note_joined_row__testing_dispatch__joined_row__packages"; then
    println "$__testing__dispatch__note_joined_row__testing_dispatch__joined_row__row"
    return 0
  fi
  @set __testing__dispatch__note_joined_row__out "$__testing__dispatch__note_joined_row__testing_dispatch__joined_row__row" '.packages' "$__testing__dispatch__note_joined_row__testing_dispatch__joined_row__packages"
  println "$__testing__dispatch__note_joined_row__out"
}

:<<'PUB_FUN'
Reads the current code review's full label set as a struct array.

Reads its forge context from environment variables:
  FORGE_REVIEW_IID       code review identifier (falls back to CI_MERGE_REQUEST_IID)
  FORGE_API_URL          forge REST API base URL (falls back to CI_API_V4_URL)
  FORGE_PROJECT_ID       forge project id (falls back to CI_PROJECT_ID)
  FORGE_TOKEN            read-scoped auth token (falls back to GITLAB_TOKEN,
                         FORGE_PR_TOKEN, CI_JOB_TOKEN)

Outside a code-review pipeline it logs and returns an empty array (so the caller
stays non-blocking); it returns 1 only on a genuine misconfiguration (missing API
URL/project/token) or an API failure. This reads the live label set from the
API, so a label added mid-review counts.

Usage: testing__review_labels
PUB_FUN
testing__review_labels() {
  __testing__review_labels__testing_dispatch__from_review__iid="${FORGE_REVIEW_IID:-${CI_MERGE_REQUEST_IID:-}}"
  if [ -z "$__testing__review_labels__testing_dispatch__from_review__iid" ]; then
    log "testing/dispatch: no code review in context (FORGE_REVIEW_IID unset); no labels to read."
    @arr __testing__review_labels__out
    println "$__testing__review_labels__out"
    return 0
  fi

  __testing__review_labels__testing_dispatch__from_review__base="${FORGE_API_URL:-${CI_API_V4_URL:-}}"
  __testing__review_labels__testing_dispatch__from_review__project="${FORGE_PROJECT_ID:-${CI_PROJECT_ID:-}}"
  __testing__review_labels__testing_dispatch__from_review__token="${FORGE_TOKEN:-${GITLAB_TOKEN:-${FORGE_PR_TOKEN:-${CI_JOB_TOKEN:-}}}}"

  if [ -z "$__testing__review_labels__testing_dispatch__from_review__base" ] || [ -z "$__testing__review_labels__testing_dispatch__from_review__project" ] || [ -z "$__testing__review_labels__testing_dispatch__from_review__token" ]; then
    error "testing/dispatch: cannot read review labels -- need FORGE_API_URL, FORGE_PROJECT_ID, and a token (FORGE_TOKEN)."
    return 1
  fi

  __testing__dispatch__fetch_labels \
    "$__testing__review_labels__testing_dispatch__from_review__base" \
    "$__testing__review_labels__testing_dispatch__from_review__project" \
    "$__testing__review_labels__testing_dispatch__from_review__iid" \
    "$__testing__review_labels__testing_dispatch__from_review__token"
}

:<<'PUB_FUN'
Reads the current code review's area/* labels and returns the bare area names.
Thin wrapper over testing__review_labels + testing__areas_from_labels.

Usage: testing__area_names_from_review
PUB_FUN
testing__area_names_from_review() {
  __testing__area_names_from_review__labels="$(testing__review_labels)" || return 1
  testing__areas_from_labels "$__testing__area_names_from_review__labels"
}

:<<'FUN'
Network seam: fetches the code review and echoes its labels as a struct array.
Isolated as its own function so tests can stub it without a live API.

Expects the forge's review endpoint to return an object with a .labels array of
label-name strings -- exactly the input testing__areas_from_labels expects.

  $1 api_base   $2 project_id   $3 iid   $4 token
FUN
__testing__dispatch__fetch_labels() {
  __testing__dispatch__fetch_labels__url="${1}/projects/${2}/merge_requests/${3}"
  @obj __testing__dispatch__fetch_labels__opts '.auth' "Bearer $4"

  __testing__dispatch__fetch_labels__resp="$(http__get \
    "$__testing__dispatch__fetch_labels__url" "$__testing__dispatch__fetch_labels__opts")" || return 1

  @arr __testing__dispatch__fetch_labels__arr_79
  @get __testing__dispatch__fetch_labels__out "$__testing__dispatch__fetch_labels__resp" '.labels' "$__testing__dispatch__fetch_labels__arr_79"
  println "$__testing__dispatch__fetch_labels__out"
}
