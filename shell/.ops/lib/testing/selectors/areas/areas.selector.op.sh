#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/testing/resolver.sh"

:<<'DOC'
The area map as a selector: a changed file maps to the area its source falls
under, a change there selects the area's tests and its importers', and a
file no area covers is one it cannot speak for. A suite marked out_of_tree
is selected whole through the declared edge its depends_on areas make, or
on any change to code when it declares none. Confidence prior: the map is
declared and derived, never observed, so it is never the reason a test is
left out.
DOC

__testing__selectors__areas__REACHING="$SHELLOPS_DIR/lib/testing/selectors/areas/reaching.awk"
@selector.areas() {
  :<<'FUN'
The map is a prior.
FUN
  @confidence() {
    println "$testing__selectors__CONFIDENCE_PRIOR"
  }

  :<<'FUN'
Selects the mapped areas' tests, importers' included, and every out-of-tree
suite the change reaches by declaration, whole; claims every changed file
some area covers by its source or as a declared test. Reads the attached
areas from the context when the caller supplied them, and derives them
otherwise.

args:
  $1  The changed files (struct array)
  $2  The context ({names, added, areas, suites, attached})
FUN
  @select() {
    @let "$2" __areas_select__ names areas suites attached
    __areas_select__unclaimed="$(testing__unmapped_for_paths \
      "$__areas_select__areas" \
      "$1"
    )" || return 1
    @difference __areas_select__claimed "$1" "$__areas_select__unclaimed"

    if ! @defined "$__areas_select__attached"; then
      __areas_select__attached="$(__testing__selectors__areas__attach \
        "$__areas_select__areas" \
        "$__areas_select__names" \
        "$__areas_select__suites"
      )" || return 1
    fi
    __areas_select__tests="$(testing__tests_for_areas \
      "$__areas_select__attached" \
      "$__areas_select__names"
    )" || return 1
    __areas_select__tests="$(__testing__selectors__areas__with_reaching_suites \
      "$__areas_select__tests" \
      "$__areas_select__suites" \
      "$__areas_select__names" \
      "$__areas_select__areas"
    )" || return 1
    @unlet __areas_select__ names areas suites attached

    @obj __at_out \
      '.tests' "$__areas_select__tests" \
      '.claimed' "$__areas_select__claimed" \
      '.unclaimed' "$__areas_select__unclaimed"
    println "$__at_out"
  }
}

:<<'FUN'
The selected tests with every out-of-tree suite the impacted areas reach by
declaration added whole: its every test file, by its root and patterns. A
suite without a root cannot be enumerated and is noted instead.

args:
  $1  The tests selected so far ({<suite>: [files]})
  $2  The effective suites
  $3  The impacted area names
  $4  The flat area map
FUN
__testing__selectors__areas__with_reaching_suites() {
  @run_awk __testing__selectors__areas__with_reaching_suites__names "$__testing__selectors__areas__REACHING" "$2" \
    --with "$3" \
    --with "$4" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" || return 1
  @len __testing__selectors__areas__with_reaching_suites__count "$__testing__selectors__areas__with_reaching_suites__names"
  __testing__selectors__areas__with_reaching_suites__acc="$1"
  __testing__selectors__areas__with_reaching_suites__i=0
  while [ "$__testing__selectors__areas__with_reaching_suites__i" -lt "$__testing__selectors__areas__with_reaching_suites__count" ]; do
    @get __testing__selectors__areas__with_reaching_suites__suite \
      "$__testing__selectors__areas__with_reaching_suites__names" \
      ".[$__testing__selectors__areas__with_reaching_suites__i]"
    @get __testing__selectors__areas__with_reaching_suites__get_1 "$2" ".\"$__testing__selectors__areas__with_reaching_suites__suite\""
    __testing__selectors__areas__with_reaching_suites__acc="$(__testing__selectors__areas__with_whole_suite \
      "$__testing__selectors__areas__with_reaching_suites__acc" \
      "$__testing__selectors__areas__with_reaching_suites__suite" \
      "$__testing__selectors__areas__with_reaching_suites__get_1"
    )" || return 1
    __testing__selectors__areas__with_reaching_suites__i=$((__testing__selectors__areas__with_reaching_suites__i + 1))
  done
  println "$__testing__selectors__areas__with_reaching_suites__acc"
}

:<<'FUN'
The selected tests with one suite's every test file set under its name, or
unchanged, with a note, for a suite with no root to enumerate under.

args:
  $1  The tests selected so far
  $2  The suite name
  $3  Its effective config
FUN
__testing__selectors__areas__with_whole_suite() {
  @get __testing__selectors__areas__with_whole_suite__root "$3" '.root' ''
  if ! @defined "$__testing__selectors__areas__with_whole_suite__root"; then
    log "testing/selectors: areas: out-of-tree suite '$2' has no root to select whole; leaving it to its runner."
    println "$1"
    return 0
  fi
  log "testing/selectors: areas: the change reaches out-of-tree suite '$2'; selecting it whole."
  @arr __testing__selectors__areas__with_whole_suite__arr_2 "$__testing__selectors__areas__with_whole_suite__root"
  __testing__selectors__areas__with_whole_suite__files="$(testing__glob_files \
    "$__testing__selectors__areas__with_whole_suite__arr_2" \
    "$(testing__suite_patterns "$3" '.glob')" \
    "$(testing__suite_patterns "$3" '.exclude')"
  )" || return 1
  @set __testing__selectors__areas__with_whole_suite__out "$1" ".\"$2\"" "$__testing__selectors__areas__with_whole_suite__files"
  println "$__testing__selectors__areas__with_whole_suite__out"
}

:<<'FUN'
The mapped areas and every area that loads one of them, with their tests
attached: what a change to the mapped areas selects from.

args:
  $1  The flat area map
  $2  The mapped area names
  $3  The effective suites
FUN
__testing__selectors__areas__attach() {
  __testing__selectors__areas__attach__reached="$(testing__with_importers "$1" "$2")" || return 1
  __testing__selectors__areas__attach__picked="$(testing__pick_areas "$1" "$__testing__selectors__areas__attach__reached")"
  testing__attach_tests "$__testing__selectors__areas__attach__picked" "$3"
}
