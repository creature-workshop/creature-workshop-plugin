#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/process/memory_cap.sh"

:<<'MODULE'
Adapter registry and contract -- the only TIA layer allowed to know a framework,
and only behind a tiny contract.

An adapter is a set of namespaced functions that know how to run one test
framework. It is identified by an id (e.g. "bats", "gotest") and must implement
the contract: for id <X>, the functions

  <X>_run_selected <suite_cfg> <file>...   run the named test files
  <X>_run_all      <suite_cfg>             run the whole suite

Both run roles receive the effective suite config (the runner's defaults overlaid
with the manifest's overrides) as their first argument. A runner reads whatever
layout it needs from it (e.g. cargo's workspace manifest path) or ignores it
(bats discovers its own files under $PROJ/test).
  <X>_suite_schema             print this runner's suite-config JSON Schema
                               fragment (pins runner via const, declares its
                               override fields, additionalProperties:false)
  <X>_suite_defaults           print this runner's default suite config (the
                               effective resolver layout: runner/root/glob/
                               discovery or whatever the runner consumes)
  <X>_strategies               (optional) the discovery strategies this runner
                               opts into beyond "default": the common ones it
                               supports (sibling/filename/embedded) and any of
                               its own. The schema composer enumerates these in
                               the runner's `discovery`; absent -> default only
  <X>_discover                 (optional) implement the runner's non-resolver
                               strategies -- any of its own, and any common
                               strategy it implements itself: "embedded", or
                               "native" -- the framework's own definition of
                               its test set, whether by executing a list
                               command (vitest) or by reading the framework's
                               metadata (cargo's package walk), keyed by area
                               via testing__files_by_area. sibling/filename are
                               resolver-owned
  <X>_coverage_summary         (optional) print the suite's last run as the
                               normalized report lib/coverage/api.sh gates on;
                               only instrumenting runners define it
  <X>_escape_key               (optional) <suite_cfg> print how the escape join
                               reads a JUnit classname this suite's run wrote: "file-path",
                               a repo-relative test file matched against the
                               record's selected files (the default when the
                               role is absent), or "package", a cargo package
                               with an optional ::binary suffix, matched against
                               the record's selected packages
  <X>_selected_packages        (optional) <suite_cfg> <file>... print the
                               packages the files narrow a run to, as a struct
                               array; a runner keyed by package defines it so
                               the record carries what the join matches
  <X>_junit_path               (optional) <suite_cfg> print the absolute path
                               of the JUnit report a run of the suite leaves
                               behind, or nothing when that run writes none;
                               the record counts the run's flaky tests from it

A runner is authored as a @runner.<X> structural-contract plugin, in
lib/testing/frameworks/<X>/<X>.runner.op.sh, whose inner roles (@run_selected,
@run_all, @suite_schema, @suite_defaults, @strategies, @discover, @discover_all,
@coverage_summary, @escape_key, @selected_packages, @junit_path) the interpreter desugars into the flat <X>_<role> functions
above. A plugin holds the contract only; frameworks.sh finds and loads it.

The two schema members make every runner a self-describing plugin: it owns its
layout DEFAULTS (suite_defaults), and the manifest-facing OVERRIDE surface plus
its VALIDATION (suite_schema). Runner layout lives entirely in those fragments,
which the effective `suites` schema COMPOSES into a discriminated union keyed on
`runner` (see testing__suites_schema), so adding a framework needs no edit to the
core manifest schema.

Unlike a single-select dispatcher, this is a registry: many adapters register at
once (no global "active backend" env var), they live inside this module, and the
contract is validated at registration time rather than merely documented -- a
misspelt or missing function fails loudly, naming the offenders.
MODULE

@arr __testing__adapter__contract run_selected run_all suite_schema suite_defaults

: <<'CONST'
The adapter contract: every registered adapter <id> must define a function
named <id>_<suffix> for each suffix in this struct array.
CONST
__testing__adapter__CONTRACT="${__testing__adapter__CONTRACT:-$__testing__adapter__contract}"

: <<'CONST'
The awk program that puts the suite-config fragments of the runners
together into one schema: a union of the runners, told apart by the runner
field.
CONST
__testing__adapter__SUITES_SCHEMA="$SHELLOPS_DIR/lib/testing/suites_schema.awk"

# CONST: Registry of adapter ids as a struct string array.
@arr __at2
__testing__adapter__REGISTRY="${__testing__adapter__REGISTRY:-$__at2}"

:<<'PUB_FUN'
Registers an adapter by id after validating that it satisfies the contract.

Fails loudly (returns 1) when any contract function is missing, naming every
absent function so the gap is obvious at load time.

Usage: testing__register_adapter "<id>"
PUB_FUN
testing__register_adapter() {
  __testing__register_adapter__missing="$(__testing__adapter__missing_contract "$1")"
  if @defined "$__testing__register_adapter__missing"; then
    error "testing__register_adapter: adapter '$1' missing contract function(s): $__testing__register_adapter__missing"
    return 1
  fi

  @wrap __testing__register_adapter__wrap_3 "$1"
  @push __testing__adapter__REGISTRY "$__testing__adapter__REGISTRY" "$__testing__register_adapter__wrap_3"
}

:<<'PUB_FUN'
Loads and registers the runner <id>, whose @runner.<id> plugin file has been
imported: the interpreter desugars its inner roles into the flat <id>_<role>
functions, and the contract check registers it. Does nothing when the runner
is already registered, so loading a runner twice is harmless. Fails, saying
what is wrong, when the plugin is missing a required role.

Usage: testing__load_runner <id>
PUB_FUN
testing__load_runner() {
  if @is_true "$(testing__adapter_registered "$1")"; then
    return 0
  fi

  command -v interpreter__load_runner >/dev/null 2>&1 \
    || import "$SHELLOPS_DIR/interpreter/api.sh"
  command -v "${1}_run_selected" >/dev/null 2>&1 \
    || interpreter__load_runner "$1" "@runner.$1" \
    || return 1

  testing__register_adapter "$1"
}

:<<'PUB_FUN'
Prints the struct boolean for whether an adapter is registered under <id>.

Usage: if @is_true "$(testing__adapter_registered "<id>")"; then ... fi
PUB_FUN
testing__adapter_registered() {
  @find __testing__adapter_registered__find_4 __testing__adapter__id_eq "$__testing__adapter__REGISTRY" "$1"
  @succeeds __testing__adapter_registered__out @defined "$__testing__adapter_registered__find_4"
  println "$__testing__adapter_registered__out"
}

:<<'PUB_FUN'
Returns the registered adapter ids as a sorted struct array ("[]" when none).

Usage: testing__adapter_ids
PUB_FUN
testing__adapter_ids() {
  @unique __testing__adapter_ids__out "$__testing__adapter__REGISTRY"
  println "$__testing__adapter_ids__out"
}

:<<'PUB_FUN'
Runs an adapter under the per-process memory cap (lib/process/memory_cap.sh),
forwarding the suite config to its run role. With no files, invokes
<id>_run_all "$suite_cfg"; with files, invokes <id>_run_selected "$suite_cfg"
"$@". Fails (returns 1) when the id is not registered.

Usage:
  testing__run "<id>" "<suite_cfg>"
  testing__run "<id>" "<suite_cfg>" file...
PUB_FUN
testing__run() {
  __testing__run__id="$1"
  __testing__run__config="$2"
  shift 2

  if @is_false "$(testing__adapter_registered "$__testing__run__id")"; then
    error "testing__run: no adapter registered for '$__testing__run__id'"
    return 1
  fi

  if [ "$#" -eq 0 ]; then
    process__memory_cap__run "${__testing__run__id}_run_all" "$__testing__run__config"
  else
    process__memory_cap__run "${__testing__run__id}_run_selected" "$__testing__run__config" "$@"
  fi
}

:<<'PUB_FUN'
Prints a runner's coverage report for the suite's last run, normalized to the
shape lib/coverage/api.sh gates on, by invoking its optional coverage_summary
role. Fails (returns 1) when the id is not registered or the runner measures no
coverage.

Usage: testing__coverage_summary "<id>" "<suite_cfg>"
PUB_FUN
testing__coverage_summary() {
  if @is_false "$(testing__adapter_registered "$1")"; then
    error "testing__coverage_summary: no adapter registered for '$1'"
    return 1
  fi
  if ! command -v "${1}_coverage_summary" >/dev/null 2>&1; then
    error "testing__coverage_summary: runner '$1' measures no coverage (no ${1}_coverage_summary role)"
    return 1
  fi

  "${1}_coverage_summary" "$2"
}

:<<'FUN'
Echoes the comma-separated contract functions <id> fails to define (empty when
the adapter is complete).

  $1 id
FUN
__testing__adapter__missing_contract() {
  @map __testing__adapter__missing_contract__fns \
    __testing__adapter__missing_fn "$__testing__adapter__CONTRACT" "$1"
  @filter __testing__adapter__missing_contract__filter_5 "$__testing__adapter__missing_contract__fns" silt__text_is_not . ''
  @join __testing__adapter__missing_contract__out "$__testing__adapter__missing_contract__filter_5" ", "
  println "$__testing__adapter__missing_contract__out"
}

:<<'FUN'
Maps one contract suffix to the function name "<id>_<suffix>" when that function
is undefined, or to "" when it is defined.

  $1 suffix (wrapped)   $2 id
FUN
__testing__adapter__missing_fn() {
  @unwrap __testing__adapter__missing_fn__unwrap_6 "$1"
  __testing__adapter__missing_fn__fn="${2}_$__testing__adapter__missing_fn__unwrap_6"
  if command -v "$__testing__adapter__missing_fn__fn" >/dev/null 2>&1; then
    printf ''
  else
    printf '%s' "$__testing__adapter__missing_fn__fn"
  fi
}

:<<'FUN'
@find predicate: true when a registry element equals the target id.

  $1 element (wrapped)   $2 target id
FUN
__testing__adapter__id_eq() {
  @unwrap __testing__adapter__id_eq__unwrap_7 "$1"
  [ "$__testing__adapter__id_eq__unwrap_7" = "$2" ]
}

:<<'PUB_FUN'
Prints a runner's default suite config -- the effective resolver layout it runs
with when a manifest sets no overrides. Falls back to "{}" for an unknown runner
(or one that predates the contract), so dispatch can overlay manifest overrides
uniformly and let the later registration check report a genuinely missing runner.

Usage: testing__suite_defaults "<runner>"
PUB_FUN
testing__suite_defaults() {
  if command -v "${1}_suite_defaults" >/dev/null 2>&1; then
    "${1}_suite_defaults"
  else
    @obj __testing__suite_defaults__out
    println "$__testing__suite_defaults__out"
  fi
}

:<<'PUB_FUN'
The discovery strategies a runner opts into, beyond the universal "default":
the common strategies it supports ("sibling"/"filename" implemented by the
resolver, "embedded"/"native" implemented by the runner) plus any of its
own. A runner declares them via the optional <id>_strategies
contract function; a runner that defines none yields [].

Usage: testing__runner_strategies "<runner>"
PUB_FUN
testing__runner_strategies() {
  if command -v "${1}_strategies" >/dev/null 2>&1; then
    "${1}_strategies"
  else
    @arr __testing__runner_strategies__out
    println "$__testing__runner_strategies__out"
  fi
}

:<<'PUB_FUN'
How the escape join reads a JUnit classname a suite's run wrote, by its
runner's optional <id>_escape_key role, which reads the suite config for a
runner whose key depends on it: "file-path" when the runner defines none.

Usage: testing__runner_escape_key "<runner>" "<suite_cfg>"
PUB_FUN
testing__runner_escape_key() {
  if command -v "${1}_escape_key" >/dev/null 2>&1; then
    "${1}_escape_key" "$2"
  else
    printf 'file-path\n'
  fi
}

:<<'PUB_FUN'
The packages a runner narrows a run to for the given test files, by its
optional <id>_selected_packages role: [] when the runner defines none, since a
runner without the role selects by file and has no packages to record.

Usage: testing__runner_selected_packages "<runner>" "<suite_cfg>" file...
PUB_FUN
testing__runner_selected_packages() {
  __testing__runner_selected_packages__runner="$1"
  shift
  if command -v "${__testing__runner_selected_packages__runner}_selected_packages" >/dev/null 2>&1; then
    "${__testing__runner_selected_packages__runner}_selected_packages" "$@"
  else
    @arr __testing__runner_selected_packages__out
    println "$__testing__runner_selected_packages__out"
  fi
}

:<<'PUB_FUN'
The absolute path of the JUnit report a run of the suite leaves behind, by its
runner's optional <id>_junit_path role: nothing when the runner defines none,
or when its role says the suite's run writes no report.

Usage: testing__runner_junit_path "<runner>" "<suite_cfg>"
PUB_FUN
testing__runner_junit_path() {
  if command -v "${1}_junit_path" >/dev/null 2>&1; then
    "${1}_junit_path" "$2"
  fi
}

:<<'PUB_FUN'
Composes the registered runners' suite-config fragments into ONE discriminated-
union JSON Schema document for the manifest's `testing.suites` entries.

Each suite value must be an object carrying a `runner` drawn from the registered
runners (a base-layer enum, so an unknown runner yields a clean error) and must
match exactly one runner's fragment. The fragments pin `runner` via const and
set additionalProperties:false, so the const makes the oneOf branches mutually
exclusive and each runner rejects another runner's fields. The fragments are
inlined into the oneOf (not $ref'd out) so the in-repo validator -- which
resolves only same-document refs -- enforces them wherever the block is embedded.

Usage: testing__suites_schema
PUB_FUN
testing__suites_schema() {
  @obj __testing__suites_schema__obj_8
  @reduce __testing__suites_schema__fragments \
    __testing__adapter__collect_fragment "$(testing__adapter_ids)" "$__testing__suites_schema__obj_8"
  @run_awk __testing__suites_schema__out "$__testing__adapter__SUITES_SCHEMA" \
    "$__testing__suites_schema__fragments" \
    --load "$SHELLOPS_DIR/lib/structs/silt/tree_edit.awk" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" || return 1
  println "$__testing__suites_schema__out"
}

:<<'FUN'
@reduce callback: sets acc.<id> to {schema, discovery} for runner <id> -- its
suite-config fragment plus the full ordered discovery enum ("default" followed
by the runner's opted-in strategies). The schema composer generates the
fragment's `discovery` property from this enum.

  $1 acc (object)   $2 id (wrapped)
FUN
__testing__adapter__collect_fragment() {
  @unwrap __testing__adapter__collect_fragment__id "$2"

  @arr __testing__adapter__collect_fragment__arr_9 default
  @concat __testing__adapter__collect_fragment__discovery \
    "$__testing__adapter__collect_fragment__arr_9" \
    "$(testing__runner_strategies "$__testing__adapter__collect_fragment__id")"

  @obj __testing__adapter__collect_fragment__entry \
    '.schema' "$("${__testing__adapter__collect_fragment__id}_suite_schema")" \
    '.discovery' "$__testing__adapter__collect_fragment__discovery"

  @set __testing__adapter__collect_fragment__out "$1" ".\"$__testing__adapter__collect_fragment__id\"" \
    "$__testing__adapter__collect_fragment__entry"
  println "$__testing__adapter__collect_fragment__out"
}

:<<'PUB_FUN'
Validates a manifest `testing.suites` object against the composed schema (the
registered-runner universe is the source of truth). Returns 0 when valid, 1 with
a diagnostic on stderr otherwise.

Usage: testing__validate_suites "$suites"
PUB_FUN
testing__validate_suites() {
  __testing__validate_suites__file="$(mktemp)"
  __testing__validate_suites__schema="$(testing__suites_schema)"
  @to_json __testing__validate_suites__json "$__testing__validate_suites__schema"
  println "$__testing__validate_suites__json" > "$__testing__validate_suites__file"
  @validate "$1" "$__testing__validate_suites__file"
  __testing__validate_suites__rc=$?
  rm -f "$__testing__validate_suites__file"
  return "$__testing__validate_suites__rc"
}

:<<'PUB_FUN'
Expands a manifest `suites` object into effective suite configs: each suite is
its runner's defaults (testing__suite_defaults) overlaid with the manifest's
overrides, the runner defaulting to the suite key.

Both the dispatch path and the scorecard normalize through here so selection
and scoring agree on the effective config (OPS-274 tracks pointing
lib/testing/dispatch.sh and lib/testing/resolver.sh here too).

  suites  {"<suite>": {"runner": <id>, <overrides>}, ...}

Usage: testing__effective_suites "$suites"
PUB_FUN
testing__effective_suites() {
  @entries __testing__effective_suites__entries_10 "$1"
  @obj __testing__effective_suites__obj_11
  @reduce __testing__effective_suites__out __testing__adapter__merge_effective "$__testing__effective_suites__entries_10" "$__testing__effective_suites__obj_11"
  println "$__testing__effective_suites__out"
}

:<<'FUN'
@reduce callback: writes one suite's effective config (runner defaults overlaid
with the manifest overrides) into the accumulating object.

args:
  $1  The accumulator (effective-suites object)
  $2  The suite entry ({key, value})
FUN
__testing__adapter__merge_effective() {
  @let "$2" __testing__adapter__merge_effective__ key value
  __testing__adapter__merge_effective__suite="$__testing__adapter__merge_effective__key"
  __testing__adapter__merge_effective__cfg="$__testing__adapter__merge_effective__value"
  @unlet __testing__adapter__merge_effective__ key value
  @get __testing__adapter__merge_effective__runner \
    "$__testing__adapter__merge_effective__cfg" \
    '.runner' \
    "$__testing__adapter__merge_effective__suite"
  @set __testing__adapter__merge_effective__cfg \
    "$__testing__adapter__merge_effective__cfg" \
    '.runner' "$__testing__adapter__merge_effective__runner" \
    '.suite' "$__testing__adapter__merge_effective__suite"
  __testing__adapter__merge_effective__defaults="$(testing__suite_defaults \
    "$__testing__adapter__merge_effective__runner")"

  @merge __testing__adapter__merge_effective__merge_12 "$__testing__adapter__merge_effective__defaults" "$__testing__adapter__merge_effective__cfg"
  @set __testing__adapter__merge_effective__out "$1" ".\"$__testing__adapter__merge_effective__suite\"" \
    "$__testing__adapter__merge_effective__merge_12"
  println "$__testing__adapter__merge_effective__out"
}

:<<'PUB_FUN'
Normalizes a suite-config pattern field (glob/exclude) to a struct array: a
string becomes a single-element array, an array passes through, anything absent
becomes []. A pattern whose text is itself valid JSON (e.g. "true") stays a
string.

args:
  $1  The suite definition
  $2  The field path (e.g. '.glob')

Usage: testing__suite_patterns "$suite_def" '.glob'
PUB_FUN
testing__suite_patterns() {
  @member __testing__suite_patterns__field "$1" "$2"
  @typeof __testing__suite_patterns__type "$__testing__suite_patterns__field"

  case "$__testing__suite_patterns__type" in
    array) println "$__testing__suite_patterns__field" ;;
    string) __testing__adapter__one_pattern "$__testing__suite_patterns__field" ;;
    *) __testing__adapter__no_patterns ;;
  esac
}

:<<'FUN'
Prints a struct array of the one pattern $1, a struct string.
FUN
__testing__adapter__one_pattern() {
  @arr __testing__adapter__one_pattern__out "$1"
  println "$__testing__adapter__one_pattern__out"
}

:<<'FUN'
Prints the empty struct array, for a suite whose field has no pattern.
FUN
__testing__adapter__no_patterns() {
  @arr __testing__adapter__no_patterns__out
  println "$__testing__adapter__no_patterns__out"
}

:<<'PUB_FUN'
Normalizes an area value's tests to a suite-keyed object: a missing or
non-object value (e.g. the legacy "[]") becomes "{}".

args:
  $1  The area value

Usage: testing__normalize_tests "$area_value"
PUB_FUN
testing__normalize_tests() {
  @obj __testing__normalize_tests__obj_14
  @get __testing__normalize_tests__tests "$1" '.tests' "$__testing__normalize_tests__obj_14"
  if @typeof __testing__normalize_tests__typeof_15 "$__testing__normalize_tests__tests"; [ "$__testing__normalize_tests__typeof_15" = "object" ]; then
    @compact __testing__normalize_tests__out "$__testing__normalize_tests__tests"
    println "$__testing__normalize_tests__out"
  else
    @obj __testing__normalize_tests__out
    println "$__testing__normalize_tests__out"
  fi
}
