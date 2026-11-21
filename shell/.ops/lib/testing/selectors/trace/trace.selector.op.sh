#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/git/commits.sh" \
  "$SHELLOPS_DIR/lib/time/api.sh" \
  "$SHELLOPS_DIR/lib/testing/trace/location.sh"

:<<'DOC'
The trace map as a selector: a review selects the tests whose recorded reads
meet its diff against the commit the map was recorded at, and whose probes
meet a file the diff adds. Confidence ground_truth: the map is what the
tests were seen to touch, so it may be the reason a test is left out.

The map is the newest one recorded at an ancestor of the checked-out head
within the age limit, read off the notes ref a traced run pushes; the diff
runs from that commit, not the merge base, so what landed between costs
precision in the safe direction. With no such map the selector claims
nothing.
DOC

__testing__selectors__trace__SELECT="$SHELLOPS_DIR/lib/testing/selectors/trace/select.awk"

@selector.trace() {
  :<<'FUN'
The map is what the tests were seen to touch.
FUN
  @confidence() {
    println "$testing__selectors__CONFIDENCE_GROUND_TRUTH"
  }

  :<<'FUN'
Selects the tests the map's reads and probes meet along the diff from its
commit to the head, and the test files the diff touches; claims the changed
files the map holds a fact about and the changed test files; and names the
tests the map holds an entry for as the ones it speaks for, so a test the
map has not seen is never left out on its word. With no usable map, selects
and claims nothing, and speaks for no test.

args:
  $1  The changed files (struct array)
  $2  The context ({names, added, areas, suites, attached})
FUN
  @select() {
    __trace_select__map="$(__testing__selectors__trace__usable_map)" || return 1
    if ! @defined "$__trace_select__map"; then
      log "testing/selectors: trace: no usable map; claiming nothing."
      __testing__selectors__trace__nothing "$1"
      return 0
    fi

    @get __trace_select__commit "$__trace_select__map" '.commit'
    __trace_select__diff="$(git__diff_name_status "$__trace_select__commit" HEAD)" || return 1
    log "testing/selectors: trace: selecting against the map recorded at $(printf '%s' "$__trace_select__commit" | cut -c1-8)."
    @split __at1 "$__trace_select__diff"
    @obj __at2
    @get __at3 "$2" '.suites' "$__at2"
    @run_awk __at_out "$__testing__selectors__trace__SELECT" "$__trace_select__map" \
      --with "$__at1" \
      --with "$1" \
      --with "$__at3" \
      --load "$SHELLOPS_DIR/lib/testing/testing.awk" || return 1
    println "$__at_out"
  }
}

:<<'FUN'
The answer of a selector with nothing to say: no tests, no claims, every
changed file unclaimed, and no test spoken for.

args:
  $1  The changed files (struct array)
FUN
__testing__selectors__trace__nothing() {
  @obj __testing__selectors__trace__nothing__obj_4
  @arr __testing__selectors__trace__nothing__arr_5
  @obj __testing__selectors__trace__nothing__obj_6
  @obj __testing__selectors__trace__nothing__out '.tests' "$__testing__selectors__trace__nothing__obj_4" '.claimed' "$__testing__selectors__trace__nothing__arr_5" '.unclaimed' "$1" '.known' "$__testing__selectors__trace__nothing__obj_6"
  println "$__testing__selectors__trace__nothing__out"
}

:<<'FUN'
Prints the newest map the selector may select by: one recorded at a commit
that is an ancestor of the checked-out head, no older than the age limit.
The map noted on the head's own history comes first; the map directory is
read only when no note qualifies. Prints nothing when none qualifies. A map
that does not read, names no commit, or was recorded off the head's history
is passed over with a note. A clone whose history stops short of the age
limit, a shallow one nobody deepened, selects by no map and says so with
a hint, since it cannot see what it would select by.
FUN
__testing__selectors__trace__usable_map() {
  __testing__selectors__trace__usable_map__cutoff="$(testing__trace__map_cutoff)"
  if @is_false "$(git__history_reaches "$__testing__selectors__trace__usable_map__cutoff")"; then
    log "testing/selectors: trace: the clone's history stops short of the map age limit, $(testing__trace__map_age_days) days; not selecting by a map."
    hint "fetch the history first: git fetch --unshallow origin. In CI, ops test fetches it."
    return 0
  fi
  __testing__selectors__trace__usable_map__noted="$(__testing__selectors__trace__usable_noted_map \
    "$__testing__selectors__trace__usable_map__cutoff"
  )" || return 1
  if @defined "$__testing__selectors__trace__usable_map__noted"; then
    println "$__testing__selectors__trace__usable_map__noted"
    return 0
  fi

  __testing__selectors__trace__usable_map__files="$(testing__trace__map_files | sort -r)"
  @defined "$__testing__selectors__trace__usable_map__files" || return 0

  println "$__testing__selectors__trace__usable_map__files" | {
    while IFS= read -r __testing__selectors__trace__usable_map__file; do
      @defined "$__testing__selectors__trace__usable_map__file" || continue
      __testing__selectors__trace__usable_map__map="$(testing__trace__read "$__testing__selectors__trace__usable_map__file")" || {
        log "testing/selectors: trace: skipping unreadable map $__testing__selectors__trace__usable_map__file"
        continue
      }
      if @is_true "$(__testing__selectors__trace__usable "$__testing__selectors__trace__usable_map__map" "$__testing__selectors__trace__usable_map__cutoff")"; then
        println "$__testing__selectors__trace__usable_map__map"
        exit 0
      fi
    done
    exit 0
  }
}

:<<'FUN'
Prints the map noted on the head's history when the selector may select by
it, nothing when no note qualifies.

args:
  $1  The cutoff timestamp (time__utc_timestamp form)
FUN
__testing__selectors__trace__usable_noted_map() {
  __testing__selectors__trace__usable_noted_map__map="$(testing__trace__noted_map)" || return 1
  @defined "$__testing__selectors__trace__usable_noted_map__map" || return 0
  if @is_true "$(__testing__selectors__trace__usable "$__testing__selectors__trace__usable_noted_map__map" "$1")"; then
    println "$__testing__selectors__trace__usable_noted_map__map"
  fi
}

:<<'FUN'
Prints true when a map may be selected by: it names a commit that is an
ancestor of the checked-out head, and was recorded at or after the cutoff.

args:
  $1  The map
  $2  The cutoff timestamp (time__utc_timestamp form)
FUN
__testing__selectors__trace__usable() {
  @get __testing__selectors__trace__usable__commit "$1" '.commit' ''
  if ! @defined "$__testing__selectors__trace__usable__commit"; then
    log "testing/selectors: trace: a map recorded outside CI names no commit; not selecting by it."
    @false __testing__selectors__trace__usable__out
    println "$__testing__selectors__trace__usable__out"
    return 0
  fi
  if @get __testing__selectors__trace__usable__get_7 "$1" '.recorded_at'; [ "$__testing__selectors__trace__usable__get_7" \< "$2" ]; then
    log "testing/selectors: trace: the map at $(printf '%s' "$__testing__selectors__trace__usable__commit" | cut -c1-8) is older than $(testing__trace__map_age_days) days; not selecting by it."
    @false __testing__selectors__trace__usable__out
    println "$__testing__selectors__trace__usable__out"
    return 0
  fi
  if @is_false "$(git__is_ancestor "$__testing__selectors__trace__usable__commit" HEAD)"; then
    log "testing/selectors: trace: the map at $(printf '%s' "$__testing__selectors__trace__usable__commit" | cut -c1-8) is not in the head's history; not selecting by it."
    @false __testing__selectors__trace__usable__out
    println "$__testing__selectors__trace__usable__out"
    return 0
  fi
  @true __testing__selectors__trace__usable__out
  println "$__testing__selectors__trace__usable__out"
}
