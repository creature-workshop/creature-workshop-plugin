#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/versions/api.sh"

: <<'MODULE'
A release tag's name as a value: the tag type, and the readers over one.
A tag names a version, on a tier with a count on the tiers that take one,
or a clean version on no tier. Each reader takes a tag the type accepts and
answers from versions__parse_version, so a tag and a version name never
disagree about what a part is. The tier words are the versions grammar's;
nothing here names one.

  tags__version "$(@tag 0.67.0-1.alpha)"  ->  0.67.0
  tags__tier "$(@tag 0.67.0-1.alpha)"     ->  alpha
  tags__count "$(@tag 0.67.0-1.alpha)"    ->  1
  tags__on_tier "$(@tag 0.66.0-dev.137)" dev  ->  true
MODULE

@load_types "$SHELLOPS_DIR/lib/tags"

: <<'PUB_FUN'
Prints the version the <tag> names, without its tier and count and without
the v a tag may lead with.

  tags__version "$(@tag v1.2.3)"          ->  1.2.3
  tags__version "$(@tag 0.67.0-1.alpha)"  ->  0.67.0
PUB_FUN
tags__version() {
  @unwrap __tags__version__name "$1"
  __tags__version__bare="$(versions__bare_version "$__tags__version__name")"
  println "${__tags__version__bare%%-*}"
}

: <<'PUB_FUN'
Prints the tier the <tag> is on, dev, alpha, beta or rc, and nothing for a
clean version, which is on no tier.

  tags__tier "$(@tag 0.67.0-1.alpha)"  ->  alpha
  tags__tier "$(@tag 1.2.3)"           ->
PUB_FUN
tags__tier() {
  @get __tags__tier__out "$(__tags__parsed "$1")" '.pre_type' ''
  println "$__tags__tier__out"
}

: <<'PUB_FUN'
Prints the <tag>'s count on its tier, read by the format the name is
written in, and nothing for a tier alone or a clean version.

  tags__count "$(@tag 0.67.0-1.alpha)"   ->  1
  tags__count "$(@tag 0.66.0-dev.137)"   ->  137
  tags__count "$(@tag 0.67.0-dev)"       ->
PUB_FUN
tags__count() {
  @get __tags__count__out "$(__tags__parsed "$1")" '.pre_inc' ''
  println "$__tags__count__out"
}

: <<'PUB_FUN'
Prints true when the <tag> is on the <tier>, and false on any other tier
and on a clean version, which is on none.

  tags__on_tier "$(@tag 0.66.0-dev.137)" dev  ->  true
  tags__on_tier "$(@tag 1.2.3)" rc            ->  false
PUB_FUN
tags__on_tier() {
  @succeeds __tags__on_tier__out [ "$(tags__tier "$1")" = "$2" ]
  println "$__tags__on_tier__out"
}

: <<'FUN'
Prints the version struct versions__parse_version reads out of the <tag>'s
name.
FUN
__tags__parsed() {
  @unwrap __tags__parsed__unwrap_1 "$1"
  versions__parse_version "$__tags__parsed__unwrap_1"
}
