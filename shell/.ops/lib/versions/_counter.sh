#!/bin/sh

: <<'FRAGMENT'
The counter format (ADR.17@global): a prerelease name spells the version's
counter, then the tier, 3.alpha, one counter shared by every tier of the
version and handed out by the tags, so tags sort in the order they were
cut; and the trunk's manifest holds the tier alone, dev, a name no tag
carries. A plan writes the tier alone, the count being the tags' to give
when the tag is cut. Reached through lib/versions/api.sh as the format
counter; it calls that module's tier ranking and never imports it, since
the module loads it.
FRAGMENT

# CONST: Where the format's names rank against another format's: below the increment form, as semver ranks a number below a word.
__versions__counter__PRECEDENCE=0

# CONST: The tier a plan with no label gravitates to.
__versions__counter__DEV="dev"

: <<'PUB_FUN'
Succeeds quietly when <pre> is a count, then a dot, then a tier, or a tier
alone, and fails quietly otherwise.

  versions__counter__is 9.dev  ->  0
  versions__counter__is dev    ->  0
  versions__counter__is dev.9  ->  1
PUB_FUN
versions__counter__is() {
  case "$1" in
    *.*.*) return 1 ;;
    *.*) @is_int "${1%%.*}" && versions__is_tier_word "${1##*.}" ;;
    *) versions__is_tier_word "$1" ;;
  esac
}

: <<'PUB_FUN'
Prints the tier of <pre>, the word after the dot or the whole of a tier
alone.
PUB_FUN
versions__counter__tier() {
  println "${1##*.}"
}

: <<'PUB_FUN'
Prints the count of <pre>, the number before the dot, and nothing for a
tier alone.
PUB_FUN
versions__counter__count() {
  case "$1" in
    *.*) println "${1%%.*}" ;;
    *) printf '\n' ;;
  esac
}

: <<'PUB_FUN'
Prints the part for <tier> at <count>, the count then the tier, and the
tier alone for no count.

  versions__counter__name rc 3   ->  3.rc
  versions__counter__name dev "" ->  dev
PUB_FUN
versions__counter__name() {
  if @defined "$2"; then
    printf '%s.%s\n' "$2" "$1"
  else
    println "$1"
  fi
}

: <<'PUB_FUN'
Reads parts on stdin and prints the key ranking each among its version's,
one per line in the same order: the format's precedence, then the count
alone, since the counter is the order the tags were cut in; a tier alone
ranks above every counted part, then by the tier's place among the tiers
(lib/versions/counter_order.awk).

  println 3.alpha dev | versions__counter__order
  ->  0.0000000003.0000000000
      0.9999999999.0000000000
PUB_FUN
versions__counter__order() {
  awk \
    -v tiers="$(versions__tier_words)" \
    -v precedence="$__versions__counter__PRECEDENCE" \
    -f "$SHELLOPS_DIR/lib/versions/tier_rank.awk" \
    -f "$SHELLOPS_DIR/lib/versions/counter_order.awk"
}

: <<'PUB_FUN'
Prints the part a plan opens a series with on <tier>: the tier alone.

  versions__counter__open alpha  ->  alpha
PUB_FUN
versions__counter__open() {
  versions__counter__name "$1" ""
}

: <<'PUB_FUN'
Prints the part a plan moves a name on <tier> at <count> to: the tier
alone, the next count being the tags' to give.

  versions__counter__bump alpha 3  ->  alpha
PUB_FUN
versions__counter__bump() {
  versions__counter__name "$1" ""
}

: <<'PUB_FUN'
Prints the part a plan with no label moves a name of <version> on <tier> at
<count> to, the dev gravity: dev alone.

  versions__counter__dev 2.0.0 alpha 3  ->  dev
PUB_FUN
versions__counter__dev() {
  versions__counter__name "$__versions__counter__DEV" ""
}

: <<'PUB_FUN'
Prints the name the next tag of <version> on <tier> takes: the version's
next counter, one past the highest any tag of the version carries whatever
its tier, in either tag form, and 1 when none does; a tag of the version in
another format carries no counter and does not count.

  versions__counter__tag 1.2.0 dev  ->  1.2.0-4.dev   (tags 1.2.0-1.dev, 1.2.0-2.dev, v1.2.0-3.alpha)
  versions__counter__tag 1.3.0 dev  ->  1.3.0-1.dev   (no tag of 1.3.0)
PUB_FUN
versions__counter__tag() {
  printf '%s-%s\n' "$1" "$(versions__counter__name "$2" "$(__versions__counter__next_count "$1")")"
}

: <<'PUB_FUN'
Prints what the trunk's manifest holds for <version> on <tier>: the tier
alone, a name no tag carries, so the tags alone carry the count.

  versions__counter__trunk 0.67.0 dev  ->  0.67.0-dev
PUB_FUN
versions__counter__trunk() {
  printf '%s-%s\n' "$1" "$(versions__counter__name "$2" "")"
}

: <<'FUN'
Prints one past the highest counter any tag of <version> carries, in either
tag form, and 1 when none does (lib/versions/last_counter.awk).
FUN
__versions__counter__next_count() {
  __versions__counter__next_count__last="$(git tag -l "$1-*" "v$1-*" 2>/dev/null \
    | awk -f "$SHELLOPS_DIR/lib/versions/last_counter.awk"
  )"

  println "$(( ${__versions__counter__next_count__last:-0} + 1 ))"
}
