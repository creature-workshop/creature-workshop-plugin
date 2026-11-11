#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/kinds/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Selectors: the plugins that answer "for these changed files, which tests",
each with the confidence its answer carries.

A selector is a plugin of kind selector (see lib/kinds/api.sh), a file
<id>.selector.op.sh defining @selector.<id>() with two roles. @confidence
prints one word of testing__selectors__CONFIDENCE: ground_truth may be the
reason a test is left out, prior is selected as it stands but is never the
last word on a file, advisory adds tests and claims nothing. @select takes
the changed files and a context ({names, added, areas, suites, attached})
and prints {tests, claimed, unclaimed}: the tests it selects by suite, the
changed files it can speak for, and the ones it cannot. A ground truth may
add known, the tests it speaks for by suite; one that names no known set
speaks for every test.

Dispatch (lib/testing/dispatch.sh) unions every selector's tests, and a file
no ground_truth or prior selector claims widens the run. When a ground truth
claims every changed file, the priors' tests are left out where a ground
truth knows them: a test no ground truth speaks for stays as the priors
selected it. A selector runs active, composed into the run, or
in shadow, recorded beside the run and composed into nothing, as the
testing config's `selectors` block sets it (testing__selectors__MODE).
Importing this module loads every selector under lib/testing/selectors.
MODULE

@enum testing__selectors__CONFIDENCE GROUND_TRUTH PRIOR ADVISORY
@enum testing__selectors__MODE ACTIVE SHADOW

__testing__selectors__ROLES="select confidence"
__testing__selectors__REQUIRED="select confidence"
__testing__selectors__DIR="$SHELLOPS_DIR/lib/testing/selectors"

: <<'PUB_FUN'
Loads and registers the selector <id>, whose plugin file has been imported,
then holds its confidence to the set: a selector answering a word outside
testing__selectors__CONFIDENCE fails to load, naming the word. See kinds__load.

Usage: testing__selectors__load <id>
PUB_FUN
testing__selectors__load() {
  kinds__load selector "$1" "$__testing__selectors__ROLES" "$__testing__selectors__REQUIRED" || return 1
  __testing__selectors__hold_confidence "$1"
}

: <<'PUB_FUN'
Finds and loads every selector under <root>; a root that is not a directory
holds none. Every selector loaded is held to the confidence set, as
testing__selectors__load holds one. See kinds__scan.

Usage: testing__selectors__load_all <root>
PUB_FUN
testing__selectors__load_all() {
  if [ ! -d "$1" ]; then
    return 0
  fi

  kinds__scan selector "$1" "$__testing__selectors__ROLES" "$__testing__selectors__REQUIRED" || return 1
  __testing__selectors__each_id __testing__selectors__hold_confidence
}

: <<'FUN'
Runs <fn> once per registered selector id, in load order, in this shell, and
stops at the first that fails, returning its status: the loop a check over
every selector needs, since a fold cannot carry a failure out.

args:
  $1  The function, called with one id
  $@  Its further arguments
FUN
__testing__selectors__each_id() {
  __testing__selectors__each_id__fn="$1"
  shift
  __testing__selectors__each_id__ids="$(kinds__names selector)"
  @len __testing__selectors__each_id__count "$__testing__selectors__each_id__ids"
  __testing__selectors__each_id__i=0
  while [ "$__testing__selectors__each_id__i" -lt "$__testing__selectors__each_id__count" ]; do
    @get __testing__selectors__each_id__id "$__testing__selectors__each_id__ids" ".[$__testing__selectors__each_id__i]"
    "$__testing__selectors__each_id__fn" "$__testing__selectors__each_id__id" "$@" || return 1
    __testing__selectors__each_id__i=$((__testing__selectors__each_id__i + 1))
  done
}

: <<'FUN'
Holds one loaded selector's confidence to the set, failing and naming the
word when it is outside it.

args:
  $1  The selector id
FUN
__testing__selectors__hold_confidence() {
  __testing__selectors__hold_confidence__word="$(kinds__call selector "$1" confidence)" || return 1
  if ! testing__selectors__CONFIDENCE_is "$__testing__selectors__hold_confidence__word"; then
    @enum_values __testing__selectors__hold_confidence__enum_values_1 testing__selectors__CONFIDENCE
    @join __testing__selectors__hold_confidence__join_2 "$__testing__selectors__hold_confidence__enum_values_1" ', '
    error "testing/selectors: selector '$1' answers confidence '$__testing__selectors__hold_confidence__word', not one of $__testing__selectors__hold_confidence__join_2"
    return 1
  fi
}

: <<'PUB_FUN'
Prints the ids of every registered selector, as a struct array, in load
order.

Usage: testing__selectors__names
PUB_FUN
testing__selectors__names() {
  kinds__names selector
}

: <<'PUB_FUN'
Prints the confidence the selector <id> answers with.

Usage: testing__selectors__confidence <id>
PUB_FUN
testing__selectors__confidence() {
  kinds__call selector "$1" confidence
}

: <<'PUB_FUN'
Prints what the selector <id> selects for the changed files in the context:
{tests, claimed, unclaimed}, as its @select role answers.

Usage: testing__selectors__select <id> <changed> <context>
PUB_FUN
testing__selectors__select() {
  kinds__call selector "$1" select "$2" "$3"
}

: <<'PUB_FUN'
Prints the mode the selector <id> runs in: what the modes name for it,
active when they name nothing. Fails, naming the word, when they name one
outside the set.

  testing__selectors__mode trace '{"trace": "shadow"}'  ->  shadow
  testing__selectors__mode areas '{"trace": "shadow"}'  ->  active

args:
  $1  The selector id
  $2  The modes ({<id>: active|shadow})
PUB_FUN
testing__selectors__mode() {
  @get __testing__selectors__mode__word "$2" ".\"$1\"" "$testing__selectors__MODE_ACTIVE"
  if ! testing__selectors__MODE_is "$__testing__selectors__mode__word"; then
    @enum_values __testing__selectors__mode__enum_values_3 testing__selectors__MODE
    @join __testing__selectors__mode__join_4 "$__testing__selectors__mode__enum_values_3" ', '
    error "testing/selectors: selector '$1' is set to mode '$__testing__selectors__mode__word', not one of $__testing__selectors__mode__join_4"
    return 1
  fi
  println "$__testing__selectors__mode__word"
}

: <<'PUB_FUN'
Prints every registered selector's answer for the changed files in the
context, as a struct array of {id, confidence, mode, tests, claimed,
unclaimed} in load order. The mode is what the context's modes ({<id>:
active|shadow}, the testing config's `selectors` block) name for the
selector, active when they name nothing. Fails, and prints nothing, when a
selector fails to answer or a mode is outside the set.

  testing__selectors__selections '["lib/string/api.sh"]' "$context"
  ->  [{"id": "areas", "confidence": "prior", "mode": "active",
        "tests": {"unit": ["test/string.api.bats"]},
        "claimed": ["lib/string/api.sh"], "unclaimed": []}]

args:
  $1  The changed files (struct array)
  $2  The context, as @select takes it, with .modes
PUB_FUN
testing__selectors__selections() {
  @arr __testing__selectors__SELECTIONS_ACC
  __testing__selectors__each_id __testing__selectors__selection "$1" "$2" || return 1
  println "$__testing__selectors__SELECTIONS_ACC"
}

: <<'FUN'
Appends one selector's answer, with its id, confidence and mode, to
__testing__selectors__SELECTIONS_ACC. Fails when the selector does not
answer or its mode is outside the set.

args:
  $1  The selector id
  $2  The changed files
  $3  The context
FUN
__testing__selectors__selection() {
  @obj __testing__selectors__selection__obj_5
  @get __testing__selectors__selection__get_6 "$3" '.modes' "$__testing__selectors__selection__obj_5"
  __testing__selectors__selection__mode="$(testing__selectors__mode \
    "$1" \
    "$__testing__selectors__selection__get_6"
  )" || return 1
  __testing__selectors__selection__answer="$(testing__selectors__select "$1" "$2" "$3")" || return 1
  @wrap __testing__selectors__selection__wrap_7 "$1"
  @wrap __testing__selectors__selection__wrap_8 "$(testing__selectors__confidence "$1")"
  @wrap __testing__selectors__selection__wrap_9 "$__testing__selectors__selection__mode"
  @set __testing__selectors__selection__answer "$__testing__selectors__selection__answer" \
    '.id' "$__testing__selectors__selection__wrap_7" \
    '.confidence' "$__testing__selectors__selection__wrap_8" \
    '.mode' "$__testing__selectors__selection__wrap_9"
  @push __testing__selectors__SELECTIONS_ACC \
    "$__testing__selectors__SELECTIONS_ACC" \
    "$__testing__selectors__selection__answer"
}

: <<'PUB_FUN'
Prints the changed files no selector that may claim a file claimed, sorted:
those left over once every claim of an active ground_truth or prior
selector is taken out. An advisory selector's claim counts for nothing
here, and a shadow selector's is recorded and composed into nothing.

  testing__selectors__unclaimed "$selections" '["lib/a.sh", "stray.sh"]'  ->  ["stray.sh"]

args:
  $1  The selections (from testing__selectors__selections)
  $2  The changed files (struct array)
PUB_FUN
testing__selectors__unclaimed() {
  __testing__selectors__unclaimed__claims="$(__testing__selectors__claims "$1")"
  @difference __testing__selectors__unclaimed__difference_10 "$2" "$__testing__selectors__unclaimed__claims"
  @unique __testing__selectors__unclaimed__out "$__testing__selectors__unclaimed__difference_10"
  println "$__testing__selectors__unclaimed__out"
}

: <<'FUN'
Prints every file an active ground_truth or prior selection claimed, once
each.

args:
  $1  The selections (from testing__selectors__selections)
FUN
__testing__selectors__claims() {
  @run_awk __testing__selectors__claims__out "$__testing__selectors__DIR/claims.awk" "$1" \
    --arg advisory "$testing__selectors__CONFIDENCE_ADVISORY" \
    --arg shadow "$testing__selectors__MODE_SHADOW" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" || return 1
  println "$__testing__selectors__claims__out"
}

: <<'PUB_FUN'
Prints the tests the run selects: the union of every active selection's
tests, per suite and de-duplicated, {} when none selected anything. When
an active ground_truth selector claims every changed file, the priors'
tests are left out where a ground truth knows them, and a test no ground
truth speaks for stays as the priors selected it.

  testing__selectors__union "$selections" '["lib/a.sh"]'  ->  {"unit": ["test/a.bats", "test/b.bats"]}

args:
  $1  The selections (from testing__selectors__selections)
  $2  The changed files (struct array)
PUB_FUN
testing__selectors__union() {
  @run_awk __testing__selectors__union__out "$__testing__selectors__DIR/union.awk" "$1" \
    --with "$2" \
    --arg prior "$testing__selectors__CONFIDENCE_PRIOR" \
    --arg ground_truth "$testing__selectors__CONFIDENCE_GROUND_TRUTH" \
    --arg shadow "$testing__selectors__MODE_SHADOW" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" || return 1
  println "$__testing__selectors__union__out"
}

: <<'PUB_FUN'
The selections as the record carries them: each selector's id, confidence,
mode, the files it claimed and the tests it contributed, so an escape is
attributable to a tier and a shadow selector is judged by what it would
have run. The unclaimed lists are left off, being the complement of the
claims.

args:
  $1  The selections (from testing__selectors__selections)
PUB_FUN
testing__selectors__attribution() {
  @run_awk __testing__selectors__attribution__out "$__testing__selectors__DIR/attribution.awk" "$1" || return 1
  println "$__testing__selectors__attribution__out"
}

testing__selectors__load_all "$__testing__selectors__DIR"
