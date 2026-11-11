#!/bin/sh

:<<'FRAGMENT'
Auto-promotion resolution: the last rung manifest.json lets the release
pipeline mint by itself (ADR 000033), and whether the hop to a given rung is
the pipeline's rather than a person's.

  bump__auto_promote_until          ->  rc
  bump__rung_is_automatic beta      ->  true
  bump__rung_is_automatic stable    ->  false
FRAGMENT

# CONST: The word a repository writes to hand no hop to the pipeline.
__bump__NO_AUTO_PROMOTION="false"

# CONST: The rung above rc, the versions library's word for a clean version.
__bump__STABLE="stable"

# CONST: Where stable stands above the four prerelease rungs the channel order ranks.
__bump__STABLE_ORDER=4

: <<'PUB_FUN'
Prints the last rung the release pipeline mints by itself, as manifest.json's
auto-promote-until declares it: a rung, dev to stable, or false when every hop
is a merge request a person approves. stable when the manifest is silent or a
repository carries none, so every rung is the pipeline's. Any other value
fails.

  <auto-promote-until: rc>  bump__auto_promote_until  ->  rc
  <no manifest>             bump__auto_promote_until  ->  stable
PUB_FUN
bump__auto_promote_until() {
  if @is_false "$(manifest__present)"; then
    __bump__check_auto_promote_until ""
    return
  fi

  __bump__auto_promote_until__until="$(manifest__get bump__auto_promote_until)" || return 1
  __bump__check_auto_promote_until "$__bump__auto_promote_until__until"
}

: <<'PUB_FUN'
Prints true when the hop to rung $1 is the pipeline's: a rung the ladder ranks
at or below the one auto-promote-until names. Prints false above that rung,
where the hop is a merge request a person approves, false for every rung when
the key is false, and false for a word the ladder does not rank.

  <auto-promote-until: rc>     bump__rung_is_automatic beta    ->  true
  <auto-promote-until: rc>     bump__rung_is_automatic stable  ->  false
  <auto-promote-until: false>  bump__rung_is_automatic alpha   ->  false
PUB_FUN
bump__rung_is_automatic() {
  __bump__rung_is_automatic__rank="$(__bump__rung_order "$1")"
  if ! @defined "$__bump__rung_is_automatic__rank"; then
    @false __bump__rung_is_automatic__out
    println "$__bump__rung_is_automatic__out"
    return
  fi

  __bump__rung_is_automatic__until="$(bump__auto_promote_until)" || return 1
  __bump__rung_is_automatic__ceiling="$(__bump__rung_order "$__bump__rung_is_automatic__until")"
  if ! @defined "$__bump__rung_is_automatic__ceiling"; then
    @false __bump__rung_is_automatic__out
    println "$__bump__rung_is_automatic__out"
    return
  fi

  @succeeds __bump__rung_is_automatic__out [ "$__bump__rung_is_automatic__rank" -le "$__bump__rung_is_automatic__ceiling" ]
  println "$__bump__rung_is_automatic__out"
}

: <<'FUN'
Prints the value $1 when a repository may declare it, a rung dev to stable or
false; fails naming the value otherwise. An empty value reads as stable, the
default a silent manifest means.

  __bump__check_auto_promote_until rc  ->  rc
  __bump__check_auto_promote_until ""  ->  stable
FUN
__bump__check_auto_promote_until() {
  __bump__check_auto_promote_until__value="${1:-$__bump__STABLE}"

  if [ "$__bump__check_auto_promote_until__value" = "$__bump__NO_AUTO_PROMOTION" ]; then
    println "$__bump__check_auto_promote_until__value"
    return 0
  fi

  if ! @defined "$(__bump__rung_order "$__bump__check_auto_promote_until__value")"; then
    error "auto-promote-until must be false, dev, alpha, beta, rc or stable, not '$1'"
    return 1
  fi

  println "$__bump__check_auto_promote_until__value"
}

: <<'FUN'
Prints where rung $1 stands on the ladder, dev at 0 up to stable at 4, and
nothing for a word the ladder does not rank. The channel order ranks a word it
does not know 0 beside dev, so the name is read back from the rank before it
counts.

  __bump__rung_order beta     ->  2
  __bump__rung_order stable   ->  4
  __bump__rung_order nightly  ->  (nothing)
FUN
__bump__rung_order() {
  if [ "$1" = "$__bump__STABLE" ]; then
    println "$__bump__STABLE_ORDER"
    return 0
  fi

  __bump__rung_order__rank="$(__bump__channel_order "$1")"
  if [ "$(__bump__channel_at "$__bump__rung_order__rank")" = "$1" ]; then
    println "$__bump__rung_order__rank"
  fi
}
