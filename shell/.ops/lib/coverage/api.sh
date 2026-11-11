#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Coverage reports and gates, independent of any language or tool.

A coverage runner (a TIA runner with a coverage_summary role) normalizes what
its tool measured into one report shape, and everything here works on that
shape alone:

  {
    "metric": "regions",
    "files": {
      "src/lib.rs": {"covered": 8, "total": 9, "suite": "unit", "runner": "llvm_cov"}
    },
    "totals": {"covered": 8, "total": 9}
  }

`metric` names what the counts count (lines, regions). Every file entry is
attributed to the suite and runner that measured it, so a report assembled from
several runs can say where each number came from. Paths are workspace-relative.

Thresholds are keyed by metric, never by runner: a threshold is a statement
about the code ("90 percent of regions"), and any run measuring that metric must
meet it. A metric with no threshold is informational.

  coverage__gate "$report" "$(@obj '.regions' 90)"
  # Total coverage: 88.89% (regions)
  # ERROR: Coverage 88.89% (regions) is below the 90% threshold

Several suites' reports of one metric merge into one (coverage__merge), and
a merged report is gated area by area (coverage__gate_areas) against the
floors the testing config's areas carry, as areas__compute_areas resolves
them: an area's files are the report's files under its paths, nested areas
included, and an inert area or one with no floor is left alone. A run of
some suites only is gated as the last full report with those suites' files
replaced by the run's (coverage__overlay), so a partial run never passes an
area on the strength of the files it did not measure.
MODULE

__coverage__DIR="$SHELLOPS_DIR/lib/coverage"

: <<'FUN'
Runs one of this module's awk programs by name, with the -v assignments that
follow it. The programs read no input; each answers from its variables in BEGIN.

  __coverage__awk percent -v covered=8 -v total=9  ->  88.89
FUN
__coverage__awk() {
  __coverage__awk__program="$1"
  shift
  awk "$@" -f "$__coverage__DIR/$__coverage__awk__program.awk"
}

: <<'PUB_FUN'
Prints a report's covered percent to two decimals. A report with nothing to
cover is fully covered, so it prints 100.00.

  coverage__percent "$report"  ->  88.89
PUB_FUN
coverage__percent() {
  @get __coverage__percent__covered "$1" '.totals.covered' 0
  @get __coverage__percent__total "$1" '.totals.total' 0

  __coverage__awk percent \
    -v covered="$__coverage__percent__covered" \
    -v total="$__coverage__percent__total"
}

: <<'PUB_FUN'
Prints a report's metric name.

  coverage__metric "$report"  ->  regions
PUB_FUN
coverage__metric() {
  @get __coverage__metric__out "$1" '.metric'
  println "$__coverage__metric__out"
}

: <<'PUB_FUN'
Prints the summary line a CI coverage regex reads (`^Total coverage: N.NN%`),
naming the metric so a reader knows lines from regions.

  coverage__summary_line "$report"  ->  Total coverage: 88.89% (regions)
PUB_FUN
coverage__summary_line() {
  printf 'Total coverage: %s%% (%s)\n' "$(coverage__percent "$1")" "$(coverage__metric "$1")"
}

: <<'PUB_FUN'
Prints true when a percent is at or above a threshold, false otherwise.

args:
  $1  The measured percent
  $2  The threshold percent
PUB_FUN
coverage__meets_threshold() {
  @succeeds __coverage__meets_threshold__out __coverage__awk meets_threshold -v percent="$1" -v threshold="$2"
  println "$__coverage__meets_threshold__out"
}

: <<'FUN'
Prints true when a value is a number a threshold can be, digits with an optional
fraction, false otherwise. A threshold that is not a number would compare as
zero and wave everything through, so the gate refuses it instead.

args:
  $1  The value
FUN
__coverage__is_number() {
  @succeeds __coverage__is_number__out __coverage__awk is_number -v value="$1"
  println "$__coverage__is_number__out"
}

: <<'PUB_FUN'
Prints the threshold that applies to a report, read from the thresholds struct by
the report's metric, or null when that metric has no threshold.

args:
  $1  The report
  $2  The thresholds struct
PUB_FUN
coverage__threshold_for() {
  @get __coverage__threshold_for__out "$2" ".\"$(coverage__metric "$1")\""
  println "$__coverage__threshold_for__out"
}

: <<'PUB_FUN'
Prints a report's summary line, then returns 1 with an error naming both numbers
when the report's metric has a threshold and the percent is below it. A metric
with no threshold reports and passes; a threshold that is not a number is an
error, never a pass.

args:
  $1  The report
  $2  The thresholds struct
PUB_FUN
coverage__gate() {
  __coverage__gate__percent="$(coverage__percent "$1")"
  __coverage__gate__threshold="$(coverage__threshold_for "$1" "$2")"

  coverage__summary_line "$1"

  if ! @defined "$__coverage__gate__threshold"; then
    return 0
  fi
  if [ "$(__coverage__is_number "$__coverage__gate__threshold")" != true ]; then
    error "Threshold for $(coverage__metric "$1") is not a number: $__coverage__gate__threshold"
    return 1
  fi
  if [ "$(coverage__meets_threshold "$__coverage__gate__percent" "$__coverage__gate__threshold")" = true ]; then
    return 0
  fi

  error "Coverage $__coverage__gate__percent% ($(coverage__metric "$1")) is below the $__coverage__gate__threshold% threshold"
  return 1
}

: <<'PUB_FUN'
Prints one file's entry of a report: what was covered out of what could be,
attributed to the suite and runner that measured it. A runner building its
report with structs puts these under the file's path, as note_file in
lib/coverage/coverage.awk does for one built with an awk program.

  coverage__file_entry 8 9 unit python  ->  {"covered":8,"total":9,"suite":"unit","runner":"python"}
PUB_FUN
coverage__file_entry() {
  @obj __coverage__file_entry__out \
    '.covered' "$1" \
    '.total' "$2" \
    '.suite' "$3" \
    '.runner' "$4"
  println "$__coverage__file_entry__out"
}

: <<'PUB_FUN'
Prints a report: the metric the counts count, the files object of entries
keyed by workspace-relative path, and the workspace totals. print_report in
lib/coverage/coverage.awk prints the same report from an awk program.

  coverage__report lines "$files" 10 12
    ->  {"metric":"lines","files":{...},"totals":{"covered":10,"total":12}}
PUB_FUN
coverage__report() {
  @obj __coverage__report__obj_1 '.covered' "$3" '.total' "$4"
  @obj __coverage__report__out \
    '.metric' "$1" \
    '.files' "$2" \
    '.totals' "$__coverage__report__obj_1"
  println "$__coverage__report__out"
}

: <<'PUB_FUN'
Prints one report from several of the same metric: the union of their files,
and the totals summed over that union. A file two suites both measured counts
once, at the entry with more covered, since the counts alone cannot say which
lines each suite reached. Fails when the reports' metrics differ, naming them,
and when there is no report at all.

  coverage__merge "$(@arr "$unit" "$pane")"
PUB_FUN
coverage__merge() {
  if @empty "$1"; then
    error "coverage__merge: no report to merge"
    return 1
  fi
  @first __coverage__merge__first_2 "$1"
  __coverage__merge__metric="$(coverage__metric "$__coverage__merge__first_2")"
  @find __coverage__merge__other __coverage__metric_differs "$1" "$__coverage__merge__metric"
  if @defined "$__coverage__merge__other"; then
    error "coverage__merge: a report measures $(coverage__metric "$__coverage__merge__other") where the first measures $__coverage__merge__metric; reports of one metric merge"
    return 1
  fi
  @obj __coverage__merge__obj_3
  @reduce __coverage__merge__files __coverage__merge_report "$1" "$__coverage__merge__obj_3"
  coverage__report \
    "$__coverage__merge__metric" \
    "$__coverage__merge__files" \
    "$(__coverage__sum "$__coverage__merge__files" covered)" \
    "$(__coverage__sum "$__coverage__merge__files" total)"
}

: <<'FUN'
Succeeds when the report's metric is not <metric>; the callback @find runs
over the reports to merge.
FUN
__coverage__metric_differs() {
  [ "$(coverage__metric "$1")" != "$2" ]
}

: <<'FUN'
@reduce callback: folds one report's files into the merged files object.

args:
  $1  The merged files so far
  $2  One report
FUN
__coverage__merge_report() {
  @obj __coverage__merge_report__obj_4
  @get __coverage__merge_report__get_5 "$2" '.files' "$__coverage__merge_report__obj_4"
  @entries __coverage__merge_report__entries_6 "$__coverage__merge_report__get_5"
  @reduce __coverage__merge_report__out __coverage__merge_file "$__coverage__merge_report__entries_6" "$1"
  println "$__coverage__merge_report__out"
}

: <<'FUN'
@reduce callback: writes one file's entry into the merged files, keeping the
entry already there when it covers more.

args:
  $1  The merged files so far
  $2  One file's entry of a report, as {key, value}
FUN
__coverage__merge_file() {
  @get __coverage__merge_file__key "$2" '.key'
  @get __coverage__merge_file__kept "$1" ".\"$__coverage__merge_file__key\".covered" ""
  if @get __coverage__merge_file__get_7 "$2" '.value.covered' 0; @defined "$__coverage__merge_file__kept" && [ "$__coverage__merge_file__kept" -ge "$__coverage__merge_file__get_7" ]; then
    println "$1"
    return 0
  fi
  @get __coverage__merge_file__get_8 "$2" '.value'
  @set __coverage__merge_file__out "$1" ".\"$__coverage__merge_file__key\"" "$__coverage__merge_file__get_8"
  println "$__coverage__merge_file__out"
}

: <<'FUN'
Prints the sum of one count, covered or total, over a files object.

  __coverage__sum "$files" covered  ->  18
FUN
__coverage__sum() {
  @entries __coverage__sum__entries_9 "$1"
  @reduce __coverage__sum__out __coverage__add "$__coverage__sum__entries_9" 0 "$2"
  println "$__coverage__sum__out"
}

: <<'FUN'
@reduce callback: adds one file's count to the running sum.

args:
  $1  The sum so far
  $2  One file's entry, as {key, value}
  $3  The count, covered or total
FUN
__coverage__add() {
  @get __coverage__add__get_10 "$2" ".value.$3" 0
  println "$(( $1 + __coverage__add__get_10 ))"
}

: <<'PUB_FUN'
Prints the report cut to the files under the given paths: a file is under a
path when it is that path or lies below it as a directory. The totals are
summed over the files kept.

  coverage__under "$report" "$(@arr workshop dashboard)"
PUB_FUN
coverage__under() {
  @obj __coverage__under__obj_11
  @get __coverage__under__get_12 "$1" '.files' "$__coverage__under__obj_11"
  @entries __coverage__under__entries_13 "$__coverage__under__get_12"
  @obj __coverage__under__obj_14
  @reduce __coverage__under__files __coverage__keep_under "$__coverage__under__entries_13" "$__coverage__under__obj_14" "$2"
  coverage__report \
    "$(coverage__metric "$1")" \
    "$__coverage__under__files" \
    "$(__coverage__sum "$__coverage__under__files" covered)" \
    "$(__coverage__sum "$__coverage__under__files" total)"
}

: <<'FUN'
@reduce callback: keeps one file's entry when the file is under any of the paths.

args:
  $1  The files kept so far
  $2  One file's entry, as {key, value}
  $3  The paths, a struct array
FUN
__coverage__keep_under() {
  if @get __coverage__keep_under__get_15 "$2" '.key'; @any __coverage__keep_under__any_16 __coverage__path_covers "$3" "$__coverage__keep_under__get_15"; @is_true "$__coverage__keep_under__any_16"; then
    @get __coverage__keep_under__get_17 "$2" '.key'
    @get __coverage__keep_under__get_18 "$2" '.value'
    @set __coverage__keep_under__out "$1" ".\"$__coverage__keep_under__get_17\"" "$__coverage__keep_under__get_18"
    println "$__coverage__keep_under__out"
    return 0
  fi
  println "$1"
}

: <<'FUN'
Succeeds when the struct string <path> is the file <file> or a directory above
it; the callback @any runs over an area's paths.
FUN
__coverage__path_covers() {
  @unwrap __coverage__path_covers__path "$1"
  case "$2" in
    "$__coverage__path_covers__path"|"$__coverage__path_covers__path"/*) return 0 ;;
    *) return 1 ;;
  esac
}

: <<'PUB_FUN'
Gates a report area by area: for every area of the computed set that is not
inert and carries a floor, prints one line with the area's percent over the
report's files under its paths and its floor, and after the last returns 1
when any area was below its floor, naming them. An area none of whose files
the report measured prints that and passes, since another report may hold
them. An area's mode must fit the report's metric: line takes lines or
regions, branch takes branches; a mismatch is an error.

  coverage__gate_areas "$report" "$(areas__compute_areas "$config")"
  # workshop: 93.10% (lines), floor 90
  # workshop.plan: 97.44% (lines), floor 97.5
  # ERROR: Coverage below the floor in: workshop.plan

args:
  $1  The report
  $2  The areas, as areas__compute_areas prints them
PUB_FUN
coverage__gate_areas() {
  @entries __coverage__gate_areas__entries_19 "$2"
  @arr __coverage__gate_areas__arr_20
  @reduce __coverage__gate_areas__failed __coverage__gate_area "$__coverage__gate_areas__entries_19" "$__coverage__gate_areas__arr_20" "$1" || return 1
  if @empty "$__coverage__gate_areas__failed"; then
    return 0
  fi
  @join __coverage__gate_areas__join_21 "$__coverage__gate_areas__failed" ", "
  error "Coverage below the floor in: $__coverage__gate_areas__join_21"
  return 1
}

: <<'FUN'
@reduce callback: gates one area and prints its line; the accumulator collects
the names of the areas below their floor.

args:
  $1  The names below their floor so far
  $2  One area, as {key, value}
  $3  The report
FUN
__coverage__gate_area() {
  @get __coverage__gate_area__name "$2" '.key'
  @get __coverage__gate_area__floor "$2" '.value.coverage.min' ""
  if @get __coverage__gate_area__get_22 "$2" '.value.inert' false; @is_true "$__coverage__gate_area__get_22" || ! @defined "$__coverage__gate_area__floor"; then
    println "$1"
    return 0
  fi
  @get __coverage__gate_area__get_23 "$2" '.value.coverage.mode' line
  __coverage__assert_mode_fits "$__coverage__gate_area__name" "$__coverage__gate_area__get_23" "$(coverage__metric "$3")" || return 1
  @arr __coverage__gate_area__arr_24
  @get __coverage__gate_area__get_25 "$2" '.value.paths' "$__coverage__gate_area__arr_24"
  __coverage__gate_area__report="$(coverage__under "$3" "$__coverage__gate_area__get_25")"
  if @get __coverage__gate_area__get_26 "$__coverage__gate_area__report" '.totals.total' 0; [ "$__coverage__gate_area__get_26" -eq 0 ]; then
    println "$__coverage__gate_area__name: no measured files" >&2
    println "$1"
    return 0
  fi
  __coverage__gate_area__percent="$(coverage__percent "$__coverage__gate_area__report")"
  println "$__coverage__gate_area__name: $__coverage__gate_area__percent% ($(coverage__metric "$3")), floor $__coverage__gate_area__floor" >&2
  if @is_true "$(coverage__meets_threshold "$__coverage__gate_area__percent" "$__coverage__gate_area__floor")"; then
    println "$1"
    return 0
  fi
  @wrap __coverage__gate_area__wrap_27 "$__coverage__gate_area__name"
  @push __coverage__gate_area__out "$1" "$__coverage__gate_area__wrap_27"
  println "$__coverage__gate_area__out"
}

: <<'FUN'
Fails, naming the area, when its coverage mode does not fit the report's
metric: line fits lines and regions, branch fits branches.

args:
  $1  The area's name
  $2  The area's mode
  $3  The report's metric
FUN
__coverage__assert_mode_fits() {
  case "$2:$3" in
    line:lines|line:regions|branch:branches) return 0 ;;
  esac
  error "coverage: area $1 asks for $2 coverage and the report measures $3"
  return 1
}

: <<'PUB_FUN'
Prints the baseline report with the run's files written over it: every file
the run measured takes the run's entry, whatever the baseline had, and every
other file keeps the baseline's, so a run of some suites is read as the last
full report would be with those suites re-run. The totals are summed over
the result. Fails when the two reports' metrics differ.

  coverage__overlay "$baseline" "$run"
PUB_FUN
coverage__overlay() {
  if [ "$(coverage__metric "$1")" != "$(coverage__metric "$2")" ]; then
    error "coverage__overlay: the baseline measures $(coverage__metric "$1") and the run measures $(coverage__metric "$2"); a run overlays a baseline of its own metric"
    return 1
  fi
  @obj __coverage__overlay__obj_28
  @get __coverage__overlay__get_29 "$2" '.files' "$__coverage__overlay__obj_28"
  @entries __coverage__overlay__entries_30 "$__coverage__overlay__get_29"
  @obj __coverage__overlay__obj_31
  @get __coverage__overlay__get_32 "$1" '.files' "$__coverage__overlay__obj_31"
  @reduce __coverage__overlay__files __coverage__overlay_file "$__coverage__overlay__entries_30" "$__coverage__overlay__get_32"
  coverage__report \
    "$(coverage__metric "$1")" \
    "$__coverage__overlay__files" \
    "$(__coverage__sum "$__coverage__overlay__files" covered)" \
    "$(__coverage__sum "$__coverage__overlay__files" total)"
}

: <<'FUN'
@reduce callback: writes one of the run's files over the baseline's files.

args:
  $1  The files so far
  $2  One file's entry of the run, as {key, value}
FUN
__coverage__overlay_file() {
  @get __coverage__overlay_file__get_33 "$2" '.key'
  @get __coverage__overlay_file__get_34 "$2" '.value'
  @set __coverage__overlay_file__out "$1" ".\"$__coverage__overlay_file__get_33\"" "$__coverage__overlay_file__get_34"
  println "$__coverage__overlay_file__out"
}
