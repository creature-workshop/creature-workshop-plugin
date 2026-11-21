#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/testing/imports/api.sh"

:<<'MODULE'
Pure, framework-agnostic core of Test Impact Analysis (TIA).

This layer knows about files, paths, and areas -- never a test framework. It
answers three questions:

  - Which areas does a set of changed files touch?
  - Which test files run for a set of areas, grouped by suite?
  - How are an area's per-suite test files derived from the filesystem?

A "suite" is the framework-shaped bucket a test belongs to (e.g. "bats", "go").
Its "runner" field is opaque here -- only the adapter layer interprets it.
Discovery draws on the git index for $PROJ, so a test is a file the repo tracks;
the matching itself is in the awk programs beside this file, run through
@run_awk.
MODULE

: <<'CONST'
This module's directory, resolved under $SHELLOPS_DIR rather than a captured
BASH_SOURCE dir (POSIX sh has none), so a relocated tree resolves the same way.
CONST
__testing__resolver__DIR="$SHELLOPS_DIR/lib/testing"

: <<'CONST'
The rules the testing awk programs share, loaded ahead of a program that
selects tests: the pathname, glob and area-coverage rules the resolver and
the scorecard both select by.
CONST
__testing__resolver__RULES="$__testing__resolver__DIR/testing.awk"

: <<'CONST'
The key the ad-hoc derivation (testing__derive_for_files) files its synthetic
area under. "new" is the reserved area name, never a real area, so it cannot
collide with a manifest area.
CONST
__testing__resolver__ADHOC_AREA="new"

:<<'FUN'
The files discovery may draw on: everything the git index holds for $PROJ, as a
struct array of $PROJ-relative paths. Outside a work tree the tree itself
stands in, so a fixture project still resolves.
FUN
__testing__resolver__tracked_files() {
  @split __testing__resolver__tracked_files__out "$(git__tracked_files "$PROJ")"
  println "$__testing__resolver__tracked_files__out"
}

:<<'PUB_FUN'
Returns the sorted, unique set of area names touched by a list of changed files.

  areas         the manifest `areas` object
  changed_files [<file>, ...]

A file belongs to an area when an area path equals the file or is a directory
prefix of it. The most specific (longest) matching path wins, so a catch-all
area never shadows a nested one. Files matching no area contribute nothing.

Usage: testing__areas_for_paths "$areas" "$changed_files"
PUB_FUN
testing__areas_for_paths() {
  @run_awk __testing__areas_for_paths__out \
    "$__testing__resolver__DIR/areas_for_paths.awk" \
    "$1" \
    --load "$__testing__resolver__RULES" \
    --with "$2" || return 1
  println "$__testing__areas_for_paths__out"
}

:<<'PUB_FUN'
The full_suite areas among the picked ones, each with the changed files whose
most specific area it is: what a run widened by a full_suite area would have
to change to narrow. Every area is passed so a file resolves as the resolver
resolves it; a picked area no file reaches is still named, with no files.

  testing__widened_by "$areas" "$picked" '["lib/git/api.sh"]'
  -> [{"area": "lib", "files": ["lib/git/api.sh"]}]

  areas    the manifest `areas` object, every area
  picked   the impacted areas (from testing__pick_areas)
  changed  [<file>, ...]

Usage: testing__widened_by "$areas" "$picked" "$changed_files"
PUB_FUN
testing__widened_by() {
  @run_awk __testing__widened_by__out \
    "$__testing__resolver__DIR/widened_by.awk" \
    "$1" \
    --load "$__testing__resolver__RULES" \
    --with "$2" \
    --with "$3" || return 1
  println "$__testing__widened_by__out"
}

:<<'PUB_FUN'
Returns the changed files that belong to no area -- the inverse of
testing__areas_for_paths. A diff with unmapped files is touching code the testmap
does not cover, which the area/* reconcile flags with area/new.

  areas         the manifest `areas` object
  changed_files [<file>, ...]

Usage: testing__unmapped_for_paths "$areas" "$changed_files"
PUB_FUN
testing__unmapped_for_paths() {
  @run_awk __testing__unmapped_for_paths__out \
    "$__testing__resolver__DIR/unmapped_for_paths.awk" \
    "$1" \
    --load "$__testing__resolver__RULES" \
    --with "$2" || return 1
  println "$__testing__unmapped_for_paths__out"
}

:<<'PUB_FUN'
Keys a flat file list by the areas whose paths cover each file -- the
area-keying half of the "native" discovery strategy. A runner asks its
framework for the test files it would run and hands them here; a file under
no area's paths is dropped.

  testing__files_by_area '["src/gl/a.test.ts"]' '{"panorama": ["src/gl"]}'
  -> {"panorama": ["src/gl/a.test.ts"]}

Usage: testing__files_by_area "$files" "$paths_by_area"
PUB_FUN
testing__files_by_area() {
  @run_awk __testing__files_by_area__out \
    "$__testing__resolver__DIR/files_by_area.awk" \
    "$1" \
    --load "$__testing__resolver__RULES" \
    --with "$2" || return 1
  println "$__testing__files_by_area__out"
}

:<<'PUB_FUN'
Returns the test files for a set of areas, grouped by suite.

  areas      the manifest `areas` object with per-suite tests attached
  area_names [<area>, ...]

Per suite, the result is the de-duplicated union of the named areas'
.tests.<suite> lists. Suites with no files are absent.

Usage: testing__tests_for_areas "$areas" "$area_names"
PUB_FUN
testing__tests_for_areas() {
  @run_awk __testing__tests_for_areas__out \
    "$__testing__resolver__DIR/tests_for_areas.awk" \
    "$1" \
    --load "$__testing__resolver__RULES" \
    --with "$2" || return 1
  println "$__testing__tests_for_areas__out"
}

:<<'PUB_FUN'
The per-suite test files derived for an ad-hoc set of source files, as if they
formed one area -- "for these files, what tests does a suite's discovery claim?".

Each suite's discovery strategies run against the files (the resolver-owned
sibling/filename, plus any the runner contributes). The result is the suite-keyed
union of what they derive, "{}" when no strategy matches any of the files.

  files   [<file>, ...]  source files, $PROJ-relative
  suites  the effective `suites` config (as testing__attach_tests takes)

Usage: testing__derive_for_files "$files" "$suites"
PUB_FUN
testing__derive_for_files() {
  @obj __testing__derive_for_files__area \
    ".\"$__testing__resolver__ADHOC_AREA\".paths" "$1"
  __testing__derive_for_files__attached="$(testing__attach_tests \
    "$__testing__derive_for_files__area" "$2")"
  @arr __testing__derive_for_files__arr_1 "$__testing__resolver__ADHOC_AREA"
  testing__tests_for_areas \
    "$__testing__derive_for_files__attached" \
    "$__testing__derive_for_files__arr_1"
}

:<<'PUB_FUN'
Restricts a flat area map to a set of area names, dropping the rest. Lets a
caller scope expensive per-area work (test discovery -- especially cargo's
per-file crate resolution) to just the areas it cares about, instead of deriving
it for all areas and selecting afterwards.

  areas      the flat area map (from areas__compute_areas)
  area_names [<area>, ...]

Usage: testing__pick_areas "$areas" "$area_names"
PUB_FUN
testing__pick_areas() {
  @run_awk __testing__pick_areas__out "$__testing__resolver__DIR/pick_areas.awk" "$1" --with "$2" || return 1
  println "$__testing__pick_areas__out"
}

:<<'PUB_FUN'
Returns the areas object with every area's .tests filled in from the filesystem
per suite: the area's own tests, none of its importers'.

Parameters:
  areas   the manifest `areas` object
  suites  {"<suite>": {"runner": .., "root": .., "glob": .., "exclude": ..,
                       "discovery": [..]}}
          `glob` and `exclude` are each a single pattern or an array of them;
          a matched file whose basename matches an exclude pattern is dropped.

For each area x suite, test files come from the strategies named in the suite's
"discovery" list, unioned with each other and with any tests already on the
area, so explicit overrides survive. Only tracked files are candidates, hidden
paths and vendored test-framework libs are skipped, and an empty or unpopulated
root yields no matches.

Only `default` is universal. `sibling` and `filename` are common strategies the
resolver owns (a runner opts in via <id>_strategies), and `embedded` is a common
name a runner implements itself. Anything else is the runner's: the resolver
calls <runner>_discover_all once per strategy when the runner defines it, and
<runner>_discover once per area otherwise.

Options:
  default   Expands to the runner's own default discovery (its suite_defaults
            .discovery), so a manifest can say "use this runner's conventions"
            explicitly.
  sibling   Files under the area's own paths matching the suite glob, emitted
            relative to $PROJ. Resolver-owned.
  filename  Tests under the suite root matching the glob whose stem matches a
            source file's stem in the area. A test stem is its basename with the
            matching glob's literal suffix removed (*.bats -> ".bats"); a source
            stem is its basename with the final extension removed (string.api.sh
            -> "string.api"; pr-hygiene -> "pr-hygiene"). Resolver-owned.
  embedded  In-source tests (e.g. Rust #[cfg(test)]). Runner-implemented via
            <id>_discover; a reserved common name no runner ships.
  native    The framework's own definition of its test set: by executing a
            list command (vitest: `vitest list`) or by reading the framework's
            metadata (cargo: the tracked Cargo.tomls), keyed to areas via
            testing__files_by_area or the runner's own ownership rule. The
            framework stays the one answer to "what is a test?".
            Runner-implemented via <id>_discover; vitest and cargo ship it.

Usage: testing__attach_own_tests "$areas" "$suites"
PUB_FUN
testing__attach_own_tests() {
  __testing__attach_own_tests__derived="$(__testing__resolver__derive_all "$1" "$2")" || return 1
  @run_awk __testing__attach_own_tests__out \
    "$__testing__resolver__DIR/attach_merge.awk" \
    "$1" \
    --load "$__testing__resolver__RULES" \
    --with "$__testing__attach_own_tests__derived" || return 1
  println "$__testing__attach_own_tests__out"
}

:<<'PUB_FUN'
Returns the areas object with every area's .tests filled in as
testing__attach_own_tests fills them, then grown by the tests of the areas that
load it (__testing__resolver__attach_importers), so a change to a module runs
what depends on it. A review asks this; a site running an adaptor's floor asks
testing__attach_own_tests.

Usage: testing__attach_tests "$areas" "$suites"
PUB_FUN
testing__attach_tests() {
  __testing__attach_tests__own="$(testing__attach_own_tests "$1" "$2")" || return 1

  __testing__resolver__attach_importers "$__testing__attach_tests__own"
}

:<<'FUN'
The attached areas with every area's .tests grown by the tests of the areas
that load it, followed to every transitive importer over the import graph of
the tracked files, so a change to a module runs what depends on it and the
manifest only names a module's own tests. Each area's .importer_tests counts
the files that added; an area that runs the full suite gains none.

  $1 attached areas (each area's own tests filled in)
FUN
__testing__resolver__attach_importers() {
  __testing__resolver__attach_importers__edges="$(__testing__resolver__import_edges)" || return 1

  @run_awk __testing__resolver__attach_importers__out \
    "$__testing__resolver__DIR/attach_importers.awk" \
    "$1" \
    --load "$__testing__resolver__RULES" \
    --with "$__testing__resolver__attach_importers__edges" || return 1
  println "$__testing__resolver__attach_importers__out"
}

:<<'FUN'
The import graph over the tracked files, as {from, to} edges.

Usage: __testing__resolver__import_edges
FUN
__testing__resolver__import_edges() {
  __testing__resolver__import_edges__edges="$(testing__imports__import_edges \
    "$(__testing__resolver__tracked_files)"
  )" || return 1
  println "$__testing__resolver__import_edges__edges"
}

:<<'PUB_FUN'
Returns the named areas together with every area that loads one of them,
however many hops away over the import graph of the tracked files, sorted.
Attaching tests over this set rather than the named areas alone is what lets
a named area gain its importers' tests: an importer the map does not hold is
an importer the attachment cannot see.

  testing__with_importers "$areas" '["lib.beta"]'  ->  ["lib.alpha","lib.beta"]

  areas  the flat area map (from areas__compute_areas), every area
  names  [<dotted-name>, ...]

Usage: testing__with_importers "$areas" "$names"
PUB_FUN
testing__with_importers() {
  __testing__with_importers__edges="$(__testing__resolver__import_edges)" || return 1

  @run_awk __testing__with_importers__out \
    "$__testing__resolver__DIR/importers_of.awk" \
    "$1" \
    --load "$__testing__resolver__RULES" \
    --with "$__testing__with_importers__edges" \
    --with "$2" || return 1
  println "$__testing__with_importers__out"
}

:<<'FUN'
The derived test files for every area x suite, as a map
{<area>: {<suite>: [files]}}. One pass over the tracked file list answers every
area and every resolver-owned strategy at once; only the strategies a runner
owns are resolved before it, area by area.

  $1 areas   $2 suites
FUN
__testing__resolver__derive_all() {
  __testing__resolver__derive_all__resolved="$(__testing__resolver__resolve_suites "$2")"
  __testing__resolver__derive_all__runner="$(__testing__resolver__runner_derived \
    "$1" "$__testing__resolver__derive_all__resolved")" || return 1

  @run_awk __testing__resolver__derive_all__out \
    "$__testing__resolver__DIR/derive_all.awk" \
    "$(__testing__resolver__tracked_files)" \
    --load "$__testing__resolver__RULES" \
    --with "$1" \
    --with "$__testing__resolver__derive_all__resolved" \
    --with "$__testing__resolver__derive_all__runner" || return 1
  println "$__testing__resolver__derive_all__out"
}

:<<'FUN'
The discovery strategies this module derives itself, in the one batched pass
over the tracked files -- and so the ones no runner is ever asked for.
FUN
__testing__resolver__resolver_owned() {
  @arr __testing__resolver__resolver_owned__out sibling filename
  println "$__testing__resolver__resolver_owned__out"
}

:<<'FUN'
The files the runner-specific discovery strategies derive, as a map
{<area>: {<suite>: [files]}} -- empty when every suite's discovery is
resolver-owned. Only a runner can resolve its own strategies: the resolver
calls <runner>_discover_all once per strategy when the runner defines it, and
<runner>_discover once per area otherwise.

  $1 areas   $2 resolved suites
FUN
__testing__resolver__runner_derived() {
  @entries __testing__resolver__runner_derived__entries_2 "$2"
  @obj __testing__resolver__runner_derived__obj_3
  @entries __testing__resolver__runner_derived__entries_4 "$1"
  @run_awk __testing__resolver__runner_derived__paths "$__testing__resolver__DIR/paths_by_area.awk" "$1" || return 1
  @reduce __testing__resolver__runner_derived__out __testing__resolver__runner_derived_suite \
    "$__testing__resolver__runner_derived__entries_2" "$__testing__resolver__runner_derived__obj_3" \
    "$__testing__resolver__runner_derived__entries_4" \
    "$(__testing__resolver__resolver_owned)" \
    "$__testing__resolver__runner_derived__paths"
  println "$__testing__resolver__runner_derived__out"
}

:<<'FUN'
@reduce callback: one suite's runner-derived files for every area. Decides
which of the runner's two discovery entry points to use, then hands the work
to that branch's helper. A suite with no runner-owned strategies contributes
nothing.

  $1 acc
  $2 suite entry
  $3 area entries
  $4 resolver-owned strategies
  $5 paths by area
FUN
__testing__resolver__runner_derived_suite() {
  @get __testing__resolver__runner_derived_suite__def "$2" '.value'

  __testing__resolver__runner_derived_suite__strategies="$(__testing__resolver__runner_strategies \
    "$__testing__resolver__runner_derived_suite__def" \
    "$4"
  )"
  @len __testing__resolver__runner_derived_suite__count "$__testing__resolver__runner_derived_suite__strategies"
  if [ "$__testing__resolver__runner_derived_suite__count" -eq 0 ]; then
    println "$1"
    return 0
  fi

  @get __testing__resolver__runner_derived_suite__runner \
    "$__testing__resolver__runner_derived_suite__def" \
    '.runner' \
    ''
  if command -v "${__testing__resolver__runner_derived_suite__runner}_discover_all" >/dev/null 2>&1; then
    __testing__resolver__batch_derived \
      "$1" \
      "$2" \
      "$__testing__resolver__runner_derived_suite__strategies" \
      "$5"
    return 0
  fi

  __testing__resolver__area_derived \
    "$1" \
    "$2" \
    "$__testing__resolver__runner_derived_suite__strategies" \
    "$3"
}

:<<'FUN'
The suite's runner-owned discovery strategies: everything its discovery list
declares beyond what the resolver resolves itself.

  $1 resolved suite def
  $2 resolver-owned strategies
FUN
__testing__resolver__runner_strategies() {
  @arr __testing__resolver__runner_strategies__arr_7
  @get __testing__resolver__runner_strategies__declared "$1" '.discovery' "$__testing__resolver__runner_strategies__arr_7"

  @difference __testing__resolver__runner_strategies__out "$__testing__resolver__runner_strategies__declared" "$2"
  println "$__testing__resolver__runner_strategies__out"
}

:<<'FUN'
One suite's runner-derived files through the batch entry point: the resolver
calls <runner>_discover_all once per strategy and merges each answer into
the map.

  $1 acc
  $2 suite entry
  $3 strategies
  $4 paths by area
FUN
__testing__resolver__batch_derived() {
  __testing__resolver__batch_derived__acc="$1"
  __testing__resolver__batch_derived__entry="$2"
  __testing__resolver__batch_derived__strategies="$3"
  __testing__resolver__batch_derived__areas="$4"

  @let "$__testing__resolver__batch_derived__entry" __testing__resolver__batch_derived__ key value
  __testing__resolver__batch_derived__def="$__testing__resolver__batch_derived__value"
  __testing__resolver__batch_derived__suite="$__testing__resolver__batch_derived__key"
  @unlet __testing__resolver__batch_derived__ key value

  @let "$__testing__resolver__batch_derived__def" __testing__resolver__batch_derived__ runner globs excludes
  @defined "$__testing__resolver__batch_derived__globs" \
    || @arr __testing__resolver__batch_derived__globs
    @defined "$__testing__resolver__batch_derived__excludes" \
    || @arr __testing__resolver__batch_derived__excludes

  @obj __testing__resolver__batch_derived__context \
    '.suite' "$__testing__resolver__batch_derived__suite" \
    '.runner' "$__testing__resolver__batch_derived__runner" \
    '.areas' "$__testing__resolver__batch_derived__areas" \
    '.globs' "$__testing__resolver__batch_derived__globs" \
    '.excludes' "$__testing__resolver__batch_derived__excludes"

  @reduce __testing__resolver__batch_derived__out __testing__resolver__runner_batch_strategy \
    "$__testing__resolver__batch_derived__strategies" \
    "$__testing__resolver__batch_derived__acc" \
    "$__testing__resolver__batch_derived__context"
  println "$__testing__resolver__batch_derived__out"
  __testing__resolver__batch_derived__status=$?
  @unlet __testing__resolver__batch_derived__ runner globs excludes
  return "$__testing__resolver__batch_derived__status"
}

:<<'FUN'
One suite's runner-derived files through the per-area entry point: the
resolver calls <runner>_discover once per area for each strategy.

  $1 acc
  $2 suite entry
  $3 strategies
  $4 area entries
FUN
__testing__resolver__area_derived() {
  __testing__resolver__area_derived__acc="$1"
  __testing__resolver__area_derived__entry="$2"
  __testing__resolver__area_derived__strategies="$3"
  __testing__resolver__area_derived__area_entries="$4"

  @let "$__testing__resolver__area_derived__entry" __testing__resolver__area_derived__ key value
  __testing__resolver__area_derived__def="$__testing__resolver__area_derived__value"
  __testing__resolver__area_derived__suite="$__testing__resolver__area_derived__key"
  @unlet __testing__resolver__area_derived__ key value

  @let "$__testing__resolver__area_derived__def" __testing__resolver__area_derived__ runner globs excludes
  @defined "$__testing__resolver__area_derived__globs" \
    || @arr __testing__resolver__area_derived__globs
    @defined "$__testing__resolver__area_derived__excludes" \
    || @arr __testing__resolver__area_derived__excludes

  @reduce __testing__resolver__area_derived__out __testing__resolver__runner_derived_area \
    "$__testing__resolver__area_derived__area_entries" \
    "$__testing__resolver__area_derived__acc" \
    "$__testing__resolver__area_derived__suite" \
    "$__testing__resolver__area_derived__runner" \
    "$__testing__resolver__area_derived__strategies" \
    "$__testing__resolver__area_derived__globs" \
    "$__testing__resolver__area_derived__excludes"
  println "$__testing__resolver__area_derived__out"
  __testing__resolver__area_derived__status=$?
  @unlet __testing__resolver__area_derived__ runner globs excludes
  return "$__testing__resolver__area_derived__status"
}

:<<'FUN'
@reduce callback: resolves one strategy through the runner's discover_all and
merges the answer into the map. The runner receives every area's paths in one
call and returns {<area>: [files]}; runner_fold.awk places each area's files
under the context's suite.

  $1 acc ({<area>: {<suite>: [files]}})
  $2 strategy (wrapped)
  $3 batch context ({suite, runner, areas, globs, excludes})
FUN
__testing__resolver__runner_batch_strategy() {
  __testing__resolver__runner_batch_strategy__acc="$1"
  @unwrap __testing__resolver__runner_batch_strategy__strategy "$2"
  __testing__resolver__runner_batch_strategy__context="$3"

  @let "$__testing__resolver__runner_batch_strategy__context" __testing__resolver__runner_batch_strategy__ suite runner areas globs excludes

  __testing__resolver__runner_batch_strategy__derived="$( \
    "${__testing__resolver__runner_batch_strategy__runner}_discover_all" \
    "$__testing__resolver__runner_batch_strategy__strategy" \
    "$__testing__resolver__runner_batch_strategy__areas" \
    "$__testing__resolver__runner_batch_strategy__globs" \
    "$__testing__resolver__runner_batch_strategy__excludes"
  )" || return 1

  @run_awk __testing__resolver__runner_batch_strategy__out \
    "$__testing__resolver__DIR/runner_fold.awk" \
    "$__testing__resolver__runner_batch_strategy__acc" \
    --load "$__testing__resolver__RULES" \
    --with "$__testing__resolver__runner_batch_strategy__derived" \
    --arg suite "$__testing__resolver__runner_batch_strategy__suite" || return 1
  println "$__testing__resolver__runner_batch_strategy__out"
  __testing__resolver__runner_batch_strategy__status=$?
  @unlet __testing__resolver__runner_batch_strategy__ suite runner areas globs excludes
  return "$__testing__resolver__runner_batch_strategy__status"
}

:<<'FUN'
@reduce callback: one area's files for one suite, keyed under both names.

  $1 acc   $2 area entry   $3 suite   $4 runner   $5 strategies   $6 globs
  $7 excludes
FUN
__testing__resolver__runner_derived_area() {
  @arr __testing__resolver__runner_derived_area__arr_8
  @get __testing__resolver__runner_derived_area__get_9 "$2" '.value.paths' "$__testing__resolver__runner_derived_area__arr_8"
  __testing__resolver__runner_derived_area__files="$(__testing__resolver__derive_suite_tests \
    "$4" "$5" "$__testing__resolver__runner_derived_area__get_9" "$6" "$7")"
  @get __testing__resolver__runner_derived_area__get_10 "$2" '.key'
  @set __testing__resolver__runner_derived_area__out "$1" ".\"$__testing__resolver__runner_derived_area__get_10\".\"$3\"" \
    "$__testing__resolver__runner_derived_area__files"
  println "$__testing__resolver__runner_derived_area__out"
}

:<<'FUN'
Resolves each suite's per-area-independent context once -- its glob/exclude
patterns and its discovery list ("default" expanded to the runner's own) --
keyed by suite name, so the per-area derivation reuses it.

  $1 suites
FUN
__testing__resolver__resolve_suites() {
  @entries __testing__resolver__resolve_suites__entries_11 "$1"
  @obj __testing__resolver__resolve_suites__obj_12
  @reduce __testing__resolver__resolve_suites__out __testing__resolver__resolve_suite "$__testing__resolver__resolve_suites__entries_11" "$__testing__resolver__resolve_suites__obj_12"
  println "$__testing__resolver__resolve_suites__out"
}

:<<'FUN'
@reduce callback: one suite's resolved context ({root, globs, excludes, runner,
discovery}), keyed under the suite name.

  $1 acc   $2 suite entry
FUN
__testing__resolver__resolve_suite() {
  @let "$2" __testing__resolver__resolve_suite__ key value
  __testing__resolver__resolve_suite__def="$__testing__resolver__resolve_suite__value"
  @let "$__testing__resolver__resolve_suite__def" __testing__resolver__resolve_suite__ root runner discovery
  @defined "$__testing__resolver__resolve_suite__discovery" \
    || @arr __testing__resolver__resolve_suite__discovery
  __testing__resolver__resolve_suite__discovery="$(__testing__resolver__expand_discovery "$__testing__resolver__resolve_suite__discovery" "$__testing__resolver__resolve_suite__runner")"
  @obj __testing__resolver__resolve_suite__resolved \
    '.root' "$__testing__resolver__resolve_suite__root" \
    '.globs' "$(testing__suite_patterns "$__testing__resolver__resolve_suite__def" '.glob')" \
    '.excludes' "$(testing__suite_patterns "$__testing__resolver__resolve_suite__def" '.exclude')" \
    '.runner' "$__testing__resolver__resolve_suite__runner" \
    '.discovery' "$__testing__resolver__resolve_suite__discovery"
  @set __testing__resolver__resolve_suite__out "$1" ".\"$__testing__resolver__resolve_suite__key\"" "$__testing__resolver__resolve_suite__resolved"
  println "$__testing__resolver__resolve_suite__out"
  __testing__resolver__resolve_suite__status=$?
  @unlet __testing__resolver__resolve_suite__ key value
  @unlet __testing__resolver__resolve_suite__ root runner discovery
  return "$__testing__resolver__resolve_suite__status"
}

:<<'FUN'
Derives one suite's runner-owned test files for an area as a sorted, unique
struct array, unioning every strategy the runner answers.

  $1 runner   $2 strategies   $3 paths   $4 globs   $5 excludes
FUN
__testing__resolver__derive_suite_tests() {
  @arr __testing__resolver__derive_suite_tests__arr_13
  @reduce __testing__resolver__derive_suite_tests__out __testing__resolver__union_strategy "$2" "$__testing__resolver__derive_suite_tests__arr_13" "$1" "$3" "$4" "$5"
  println "$__testing__resolver__derive_suite_tests__out"
}

:<<'FUN'
Expands a discovery list, replacing each "default" entry with the runner's own
default discovery (its suite_defaults .discovery). Other entries pass through.
Deduplicated so a list naming both "default" and an explicit default strategy
does not run it twice.

  $1 discovery (struct array)   $2 runner
FUN
__testing__resolver__expand_discovery() {
  @arr __testing__resolver__expand_discovery__arr_14
  @reduce __testing__resolver__expand_discovery__reduce_15 __testing__resolver__expand_strategy "$1" "$__testing__resolver__expand_discovery__arr_14" "$2"
  @unique __testing__resolver__expand_discovery__out "$__testing__resolver__expand_discovery__reduce_15"
  println "$__testing__resolver__expand_discovery__out"
}

:<<'FUN'
@reduce callback: appends one discovery entry, expanding "default" to the
runner's default discovery list.

  $1 acc   $2 strategy (wrapped)   $3 runner
FUN
__testing__resolver__expand_strategy() {
  if @unwrap __testing__resolver__expand_strategy__unwrap_16 "$2"; [ "$__testing__resolver__expand_strategy__unwrap_16" = "default" ]; then
    @arr __testing__resolver__expand_strategy__arr_17
    @get __testing__resolver__expand_strategy__get_18 "$(testing__suite_defaults "$3")" '.discovery' "$__testing__resolver__expand_strategy__arr_17"
    @concat __testing__resolver__expand_strategy__out "$1" "$__testing__resolver__expand_strategy__get_18"
    println "$__testing__resolver__expand_strategy__out"
  else
    @push __testing__resolver__expand_strategy__out "$1" "$2"
    println "$__testing__resolver__expand_strategy__out"
  fi
}

:<<'FUN'
@reduce callback: unions one strategy's files into the accumulating array.

  $1 acc   $2 strategy (wrapped)   $3 runner   $4 paths   $5 globs   $6 excludes
FUN
__testing__resolver__union_strategy() {
  @unwrap __testing__resolver__union_strategy__unwrap_19 "$2"
  __testing__resolver__union_strategy__files="$(__testing__resolver__runner_discover \
    "$3" "$__testing__resolver__union_strategy__unwrap_19" "$4" "$5" "$6")"
  @concat __testing__resolver__union_strategy__concat_20 "$1" "$__testing__resolver__union_strategy__files"
  @unique __testing__resolver__union_strategy__out "$__testing__resolver__union_strategy__concat_20"
  println "$__testing__resolver__union_strategy__out"
}

:<<'FUN'
Dispatches a runner-specific discovery strategy to <runner>_discover, or yields
[] when the runner defines no such callback.

  $1 runner   $2 strategy   $3 paths   $4 globs   $5 excludes
FUN
__testing__resolver__runner_discover() {
  if command -v "${1}_discover" >/dev/null 2>&1; then
    "${1}_discover" "$2" "$3" "$4" "$5"
  else
    @arr __testing__resolver__runner_discover__out
    println "$__testing__resolver__runner_discover__out"
  fi
}

:<<'PUB_FUN'
Files at or under the given paths whose basename matches any of the globs, minus
any matching an exclude pattern, as a sorted, unique struct array of
$PROJ-relative paths. Shared by runner-implemented strategies (e.g. cargo's
native package walk) so multi-glob/exclude semantics live in one place.

  $1 paths (struct array)   $2 globs (struct array)   $3 excludes (struct array)
PUB_FUN
testing__glob_files() {
  @run_awk __testing__glob_files__out \
    "$__testing__resolver__DIR/glob_files.awk" \
    "$(__testing__resolver__tracked_files)" \
    --load "$__testing__resolver__RULES" \
    --with "$1" \
    --with "$2" \
    --with "$3" || return 1
  println "$__testing__glob_files__out"
}

:<<'PUB_FUN'
The by-area form of testing__glob_files: the matching files under each area's
paths, for every area in one pass over the tracked file list, as
{"<area>": [<file>, ...]}. Each area's list is sorted and unique, and an area
whose paths match nothing is absent. A runner's batch discovery gathers its
candidate files with this.

  $1 paths by area ({<area>: [<path>, ...]})
  $2 globs (struct array)
  $3 excludes (struct array)
PUB_FUN
testing__glob_files_by_area() {

  @run_awk __testing__glob_files_by_area__out \
    "$__testing__resolver__DIR/glob_files_by_area.awk" \
    "$(__testing__resolver__tracked_files)" \
    --load "$__testing__resolver__RULES" \
    --with "$2" \
    --with "$3" \
    --with "$1" || return 1
  println "$__testing__glob_files_by_area__out"
}

:<<'PUB_FUN'
The names of the areas in an attached map that are neither declared inert nor
attached to any test, sorted. Selection has nothing to run for such an area,
and nothing to run proves nothing: it is a gap in the mapping, not a no-code
declaration.

  testing__untested_areas '{"docs":{"tests":{},"inert":true},"builtins":{"tests":{},"inert":false}}'
  -> ["builtins"]

  $1 attached areas (from testing__attach_tests)
PUB_FUN
testing__untested_areas() {
  @run_awk __testing__untested_areas__out \
    "$__testing__resolver__DIR/untested_areas.awk" \
    "$1" \
    --load "$__testing__resolver__RULES" || return 1
  println "$__testing__untested_areas__out"
}
