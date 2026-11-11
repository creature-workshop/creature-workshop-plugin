#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/certification/api.sh" \
  "$SHELLOPS_DIR/lib/forge/api.sh" \
  "$SHELLOPS_DIR/lib/manifest/api.sh" \
  "$SHELLOPS_DIR/lib/promotion/api.sh"

: <<'MODULE'
A rung is earned before its tag is minted (ADR 000025). Before a promotion
tags a merge, the merge earns every certification the ladder names for the
rung (lib/promotion/api.sh), each asked once with the candidate
(lib/certification/api.sh), and every verdict must be green. A stable
version is never a candidate: the rc below it stands for it, under the
review that gates stable (ADR 000025).
MODULE

# CONST: The rung a clean version sits on, the versions library's word for it.
__releases__candidate__STABLE="stable"

: <<'PUB_FUN'
Asks every certification the ladder names for <version>'s rung about <sha>,
its candidate. When there is nothing to prove, no version planned, no
ladder declared, a stable version, or a rung that needs no certification,
it says so and succeeds.
Non-zero when the ladder does not climb the rung, a certification could not
be carried out, or any verdict is not green, naming each that was not.

Usage: releases__release_candidate <sha> <version>
PUB_FUN
releases__release_candidate() {
  __releases__release_candidate__names="$(__releases__candidate__certifications "$2")" || return 1

  if @empty "$__releases__release_candidate__names"; then
    return 0
  fi

  @join __releases__release_candidate__join_1 "$__releases__release_candidate__names" ", "
  log "Proving ${1} as the candidate for ${2}: $__releases__release_candidate__join_1."
  __releases__release_candidate__verdicts="$(__releases__candidate__verdicts "$__releases__release_candidate__names" "$1")" || return 1

  __releases__candidate__verdict "$__releases__release_candidate__verdicts" "$1" "$2"
}

: <<'FUN'
Prints the certifications a candidate for <version> must earn, a struct
array of names in the ladder's order; or an empty array when there is
nothing to prove, saying why in the log: no version was planned, no ladder
is declared, the version is stable, or its rung needs no certification.
Fails when the ladder does not climb the version's rung.

  __releases__candidate__certifications 1.2.0-beta.1  ->  ["beta"]
  __releases__candidate__certifications 1.2.0         ->  []

Usage: __releases__candidate__certifications <version>
FUN
__releases__candidate__certifications() {
  if ! @defined "${1:-}"; then
    log "No version is planned, so there is no candidate to prove."
    @arr __releases__candidate__certifications__out
    println "$__releases__candidate__certifications__out"
    return 0
  fi

  __releases__candidate__certifications__ladder="$(promotion__declared)" || return 1
  if ! @defined "$__releases__candidate__certifications__ladder"; then
    log "Nothing to prove: no ladder is declared."
    @arr __releases__candidate__certifications__out
    println "$__releases__candidate__certifications__out"
    return 0
  fi

  __releases__candidate__certifications__rung="$(promotion__rung_of_version "$1")" || return 1

  if [ "$__releases__candidate__certifications__rung" = "$__releases__candidate__STABLE" ]; then
    log "A stable version is never a candidate: the rc below it stands for ${1} (ADR 000025)."
    @arr __releases__candidate__certifications__out
    println "$__releases__candidate__certifications__out"
    return 0
  fi

  __releases__candidate__certifications__names="$(promotion__certifies "$__releases__candidate__certifications__ladder" "$__releases__candidate__certifications__rung")" || return 1

  if @empty "$__releases__candidate__certifications__names"; then
    log "Nothing to prove: the ${__releases__candidate__certifications__rung} rung needs no certification."
  fi

  println "$__releases__candidate__certifications__names"
}

: <<'FUN'
Prints the verdicts of every certification <names> names on <sha>, in
order, as one struct array. Fails when one is unknown or could not be
carried out, and asks none after it.

Usage: __releases__candidate__verdicts <names> <sha>
FUN
__releases__candidate__verdicts() {
  @arr __releases__candidate__verdicts__all
  @join __releases__candidate__verdicts__join_2 "$1" ' '
  for __releases__candidate__verdicts__name in $__releases__candidate__verdicts__join_2; do
    __releases__candidate__verdicts__one="$(certification__certify "$__releases__candidate__verdicts__name" "$2")" || return 1
    @concat __releases__candidate__verdicts__all "$__releases__candidate__verdicts__all" "$__releases__candidate__verdicts__one"
  done
  println "$__releases__candidate__verdicts__all"
}

: <<'FUN'
Reads the verdict off <verdicts>, the checks on <sha> as the candidate for
<version>: no check anywhere, and nothing stands between the version and
its tag; green everywhere, and it may be tagged; red anywhere, and the call
fails naming each verdict that was not green.

Usage: __releases__candidate__verdict <verdicts> <sha> <version>
FUN
__releases__candidate__verdict() {
  if @empty "$1"; then
    log "No certification checked anything on ${2}; nothing stands between ${3} and its tag."
    return 0
  fi

  @filter __releases__candidate__verdict__red "$1" silt__text_is_not .state "$forge__OUTCOME_SUCCESS"

  if ! @empty "$__releases__candidate__verdict__red"; then
    error "release: ${2} is not proven as the candidate for ${3}; red: $(__releases__candidate__describe "$__releases__candidate__verdict__red")."
    return 1
  fi

  log "Every check on ${2} is green; ${3} may be tagged."
}

: <<'FUN'
Prints the red verdicts <verdicts> as one line a reader can act on.

  __releases__candidate__describe '[{"check": "staging-github", "state": "failure", "url": "https://x/1"}]'
    ->  staging-github failure https://x/1
FUN
__releases__candidate__describe() {
  @map __releases__candidate__describe__map_3 __releases__candidate__describe_one "$1"
  @join __releases__candidate__describe__out "$__releases__candidate__describe__map_3" "; "
  println "$__releases__candidate__describe__out"
}

: <<'FUN'
@map callback: one red verdict <element> as its check, state and run.
FUN
__releases__candidate__describe_one() {
  @get __releases__candidate__describe_one__get_4 "$1" '.check' ''
  @get __releases__candidate__describe_one__get_5 "$1" '.state' ''
  @get __releases__candidate__describe_one__get_6 "$1" '.url' ''
  printf '%s %s %s\n' \
    "$__releases__candidate__describe_one__get_4" \
    "$__releases__candidate__describe_one__get_5" \
    "$__releases__candidate__describe_one__get_6"
}
