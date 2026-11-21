#!/bin/sh

: <<'FRAGMENT'
The increment format: a prerelease name spells the tier, then a count of
its own, dev.9, and every tier of a version counts on its own. It is the
format of every tag cut before a repository takes ADR.17@global's names,
and the one such a repository writes. Reached through lib/versions/api.sh
as the format increment; it calls that module's tier ranking and never
imports it, since the module loads it.
FRAGMENT

# CONST: Where the format's names rank against another format's: above the counter form, as semver ranks a word above a number.
__versions__increment__PRECEDENCE=1

# CONST: The tier a plan with no label gravitates to.
__versions__increment__DEV="dev"

: <<'PUB_FUN'
Succeeds quietly when <pre> is a tier, then a dot, then a count, and
fails quietly otherwise.

  versions__increment__is dev.9  ->  0
  versions__increment__is 9.dev  ->  1
  versions__increment__is dev    ->  1
PUB_FUN
versions__increment__is() {
  case "$1" in
    *.*.*) return 1 ;;
    *.*) versions__is_tier_word "${1%%.*}" && @is_int "${1##*.}" ;;
    *) return 1 ;;
  esac
}

: <<'PUB_FUN'
Prints the tier of <pre>, the word before the dot.
PUB_FUN
versions__increment__tier() {
  println "${1%%.*}"
}

: <<'PUB_FUN'
Prints the count of <pre>, the number after the dot.
PUB_FUN
versions__increment__count() {
  println "${1##*.}"
}

: <<'PUB_FUN'
Prints the part for <tier> at <count>, the tier then its count, and the
tier alone for no count.

  versions__increment__name rc 3  ->  rc.3
PUB_FUN
versions__increment__name() {
  if @defined "$2"; then
    printf '%s.%s\n' "$1" "$2"
  else
    println "$1"
  fi
}

: <<'PUB_FUN'
Reads parts on stdin and prints the key ranking each among its version's,
one per line in the same order: the format's precedence, then the tier's
place among the tiers, then the count (lib/versions/increment_order.awk).

  println beta.2 | versions__increment__order  ->  1.0000000002.0000000002
PUB_FUN
versions__increment__order() {
  awk \
    -v tiers="$(versions__tier_words)" \
    -v precedence="$__versions__increment__PRECEDENCE" \
    -f "$SHELLOPS_DIR/lib/versions/tier_rank.awk" \
    -f "$SHELLOPS_DIR/lib/versions/increment_order.awk"
}

: <<'PUB_FUN'
Prints the part a plan opens a series with on <tier>: its first count.

  versions__increment__open alpha  ->  alpha.1
PUB_FUN
versions__increment__open() {
  versions__increment__name "$1" 1
}

: <<'PUB_FUN'
Prints the part a plan moves a name on <tier> at <count> to: the next count
on the same tier.

  versions__increment__bump alpha 2  ->  alpha.3
PUB_FUN
versions__increment__bump() {
  versions__increment__name "$1" "$(( ${2:-0} + 1 ))"
}

: <<'PUB_FUN'
Prints the part a plan with no label moves a name of <version> on <tier> at
<count> to, the dev gravity: the next dev on the dev tier, and the first
dev no tag of <version> holds from any other tier.

  versions__increment__dev 2.0.0 dev 5    ->  dev.6
  versions__increment__dev 2.0.0 alpha 1  ->  dev.N, N past every 2.0.0-dev.* tag
PUB_FUN
versions__increment__dev() {
  if [ "$2" = "$__versions__increment__DEV" ]; then
    versions__increment__bump "$2" "$3"
    return 0
  fi

  versions__increment__name "$__versions__increment__DEV" "$(__versions__increment__next_count "$1" "$__versions__increment__DEV")"
}

: <<'PUB_FUN'
Prints the name the next tag of <version> on <tier> takes: the tier at one
past the highest count any tag of the version carries on it, in either tag
form.

  versions__increment__tag 1.2.0 dev  ->  1.2.0-dev.4   (tags 1.2.0-dev.1 to v1.2.0-dev.3)
PUB_FUN
versions__increment__tag() {
  printf '%s-%s\n' "$1" "$(versions__increment__name "$2" "$(__versions__increment__next_count "$1" "$2")")"
}

: <<'FUN'
Prints one past the highest count any tag of <version> carries on <tier>,
in either tag form, and 1 when none does.
FUN
__versions__increment__next_count() {
  __versions__increment__next_count__prefix="$1-$2."
  # structs-lint: allow -- the count is read off the tag names by their prefix, not held to a spelling
  __versions__increment__next_count__last="$(git tag -l "${__versions__increment__next_count__prefix}*" "v${__versions__increment__next_count__prefix}*" 2>/dev/null \
    | sed "s|^v\{0,1\}${__versions__increment__next_count__prefix}||" \
    | sort -rn \
    | head -1
  )"

  println "$(( ${__versions__increment__next_count__last:-0} + 1 ))"
}
