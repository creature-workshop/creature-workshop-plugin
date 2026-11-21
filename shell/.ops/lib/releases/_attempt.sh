#!/bin/sh
import \
  "$SHELLOPS_DIR/lib/bump/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/git/commits.sh" \
  "$SHELLOPS_DIR/lib/git/remotes.sh" \
  "$SHELLOPS_DIR/lib/git/tags.sh" \
  "$SHELLOPS_DIR/lib/releases/_certified.sh" \
  "$SHELLOPS_DIR/lib/releases/candidate.sh" \
  "$SHELLOPS_DIR/lib/releases/reach.sh" \
  "$SHELLOPS_DIR/lib/releases/record/api.sh" \
  "$SHELLOPS_DIR/lib/releases/record/commit.sh" \
  "$SHELLOPS_DIR/lib/versions/api.sh"

: <<'MODULE'
A certification attempt (ADR.44@shellops). It takes one commit, the
candidate, through alpha, beta and rc in order, up to the tier
auto-promote-until names.

For each tier the attempt:

  1. runs the tier's certifications on the candidate,
  2. writes the release commit for the tier and pushes it to origin with
     its tag,
  3. promotes that tag to the tier's sites.

A step that fails stops the attempt. No later tier is cut.

A second run on the same candidate cuts no second tag for a tier that
already has one. It promotes the existing tag and goes on from there.

  releases__attempt__run 9a02...
    ->  {"candidate": "9a02...", "version": "0.67.0",
         "earned": ["0.67.0-1.alpha", "0.67.0-1.beta", "0.67.0-1.rc"], "stopped": null}
MODULE

# CONST: The remote an attempt reads tags from and pushes release commits to.
__releases__attempt__REMOTE="origin"

: <<'PUB_FUN'
Runs an attempt on <candidate> and prints the outcome:

  candidate  The commit.
  version    Its version.
  earned     The tags cut and promoted, in order.
  stopped    The tier that failed, or null.

Fails when a tier failed, or when <candidate> is not a commit or has no
version.

  releases__attempt__run 9a02...
    ->  {"candidate": "9a02...", "version": "0.67.0", "earned": [...], "stopped": null}

Usage: releases__attempt__run <candidate>
PUB_FUN
releases__attempt__run() {
  __releases__attempt__run__candidate="$(git__commit_of "$1")" || return 1
  __releases__attempt__run__version="$(releases__attempt__version "$__releases__attempt__run__candidate")" || return 1
  __releases__attempt__run__tiers="$(releases__attempt__tiers)" || return 1

  __releases__attempt__announce \
    "$__releases__attempt__run__candidate" \
    "$__releases__attempt__run__version" \
    "$__releases__attempt__run__tiers"

  __releases__attempt__run__start="$(__releases__attempt__outcome \
    "$__releases__attempt__run__candidate" \
    "$__releases__attempt__run__version"
  )"
  @last __releases__attempt__run__last "$__releases__attempt__run__tiers"
  @unwrap __releases__attempt__run__top "$__releases__attempt__run__last"
  @reduce __releases__attempt__run__outcome \
    __releases__attempt__earn \
    "$__releases__attempt__run__tiers" \
    "$__releases__attempt__run__start" \
    "$__releases__attempt__run__top"

  println "$__releases__attempt__run__outcome"
  __releases__attempt__ran_through "$__releases__attempt__run__outcome"
}

: <<'FUN'
Logs the candidate, the version and the tiers of the attempt that starts.
FUN
__releases__attempt__announce() {
  @join __releases__attempt__announce__tiers "$3" ' '
  log "Attempt on ${1}: ${2}, tiers ${__releases__attempt__announce__tiers}."
}

: <<'FUN'
Prints the outcome of an attempt that has not run a tier yet.
FUN
__releases__attempt__outcome() {
  @arr __releases__attempt__outcome__arr_1
  @null __releases__attempt__outcome__null_2
  @obj __releases__attempt__outcome__out \
    '.candidate' "$1" \
    '.version' "$2" \
    '.earned' "$__releases__attempt__outcome__arr_1" \
    '.stopped' "$__releases__attempt__outcome__null_2"
  println "$__releases__attempt__outcome__out"
}

: <<'FUN'
@reduce callback. Runs <tier> and prints the outcome with the tier's tag
added to earned, or with stopped set to the tier when it fails. Runs
nothing once the outcome has stopped. <top> is the attempt's last tier.
  $1 outcome   $2 tier   $3 top
FUN
__releases__attempt__earn() {
  @unwrap __releases__attempt__earn__tier "$2"
  if ! @is_true "$(__releases__attempt__running "$1")"; then
    println "$1"
    return 0
  fi
  if @succeeds __releases__attempt__earn__succeeds_5 [ "$__releases__attempt__earn__tier" = "$3" ]; @get __releases__attempt__earn__get_4 "$1" '.version'; @get __releases__attempt__earn__get_3 "$1" '.candidate'; __releases__attempt__earn__name="$(releases__attempt__tier \
    "$__releases__attempt__earn__get_3" \
    "$__releases__attempt__earn__get_4" \
    "$__releases__attempt__earn__tier" \
    "$__releases__attempt__earn__succeeds_5"
  )"; then
    @get __releases__attempt__earn__get_6 "$1" '.earned'
    @push __releases__attempt__earn__push_7 "$__releases__attempt__earn__get_6" "$__releases__attempt__earn__name"
    @set __releases__attempt__earn__out "$1" '.earned' "$__releases__attempt__earn__push_7"
    println "$__releases__attempt__earn__out"
    return 0
  fi
  @set __releases__attempt__earn__out "$1" '.stopped' "$__releases__attempt__earn__tier"
  println "$__releases__attempt__earn__out"
}

: <<'FUN'
Prints true while the <outcome> has not stopped, false once it has.
FUN
__releases__attempt__running() {
  @get __releases__attempt__running__get_8 "$1" '.stopped'
  @null __releases__attempt__running__null_9
  @succeeds __releases__attempt__running__out [ "$__releases__attempt__running__get_8" = "$__releases__attempt__running__null_9" ]
  println "$__releases__attempt__running__out"
}

: <<'FUN'
Succeeds when the <outcome> has not stopped, and fails when it has.
FUN
__releases__attempt__ran_through() {
  @is_true "$(__releases__attempt__running "$1")"
}

: <<'PUB_FUN'
Prints the version of <candidate>, read from the latest release in its
.ops/lock. Fails when the commit has no lock or the lock has no version.

  releases__attempt__version 9a02...  ->  0.67.0   (lock: 0.67.0-dev)

Usage: releases__attempt__version <candidate>
PUB_FUN
releases__attempt__version() {
  __releases__attempt__version__lock="$(git__file_at "$1" .ops/lock)" || {
    error "attempt: ${1} holds no lock, so it is on no version."
    return 1
  }
  @get __releases__attempt__version__latest "$__releases__attempt__version__lock" '.release.latest' ''
  if ! @defined "$__releases__attempt__version__latest"; then
    error "attempt: the lock at ${1} records no latest version."
    return 1
  fi
  versions__version_of "$__releases__attempt__version__latest"
}

: <<'PUB_FUN'
Prints the tiers an attempt runs, in order: every tier above dev, up to
the one auto-promote-until names (ADR 000033). Stable is never one of them.

  <auto-promote-until: rc>    releases__attempt__tiers  ->  ["alpha", "beta", "rc"]
  <auto-promote-until: beta>  releases__attempt__tiers  ->  ["alpha", "beta"]

Usage: releases__attempt__tiers
PUB_FUN
releases__attempt__tiers() {
  # shellcheck disable=SC2046  # the tier words split into one element each
  @arr __releases__attempt__tiers__arr_10 $(versions__tier_words)
  @arr __releases__attempt__tiers__arr_11
  @reduce __releases__attempt__tiers__out __releases__attempt__keep_automatic "$__releases__attempt__tiers__arr_10" "$__releases__attempt__tiers__arr_11"
  # shellcheck disable=SC2046 # the tier words split into the array's elements on purpose
  println "$__releases__attempt__tiers__out"
}

: <<'FUN'
@reduce callback. Prints <acc> with <tier> added when an attempt runs that
tier, and unchanged for dev or a tier above auto-promote-until.
  $1 acc   $2 tier
FUN
__releases__attempt__keep_automatic() {
  @unwrap __releases__attempt__keep_automatic__tier "$2"
  if [ "$(versions__tier_rank "$__releases__attempt__keep_automatic__tier")" -eq 0 ]; then
    println "$1"
    return 0
  fi
  if @is_true "$(bump__rung_is_automatic "$__releases__attempt__keep_automatic__tier")"; then
    @push __releases__attempt__keep_automatic__out "$1" "$__releases__attempt__keep_automatic__tier"
    println "$__releases__attempt__keep_automatic__out"
    return 0
  fi
  println "$1"
}

: <<'PUB_FUN'
Runs one tier for <candidate>: cuts the tier's tag, promotes it to the
tier's sites, and prints the tag. Fails when the tag cannot be cut or a
site refuses it. <top> is true for the attempt's last tier.

  releases__attempt__tier 9a02... 0.67.0 rc true  ->  0.67.0-1.rc

Usage: releases__attempt__tier <candidate> <version> <tier> <top>
PUB_FUN
releases__attempt__tier() {
  __releases__attempt__tier__candidate="$1"
  __releases__attempt__tier__version="$2"
  __releases__attempt__tier__tier="$3"
  __releases__attempt__tier__top="$4"

  git__remotes__fetch_tags "$__releases__attempt__REMOTE" || return 1

  __releases__attempt__tier__name="$(__releases__attempt__record \
    "$__releases__attempt__tier__candidate" \
    "$__releases__attempt__tier__version" \
    "$__releases__attempt__tier__tier" \
    "$__releases__attempt__tier__top"
  )" || return 1
  __releases__attempt__promote "$__releases__attempt__tier__tier" "$__releases__attempt__tier__name" || return 1

  println "$__releases__attempt__tier__name"
}

: <<'FUN'
Prints the tag of <tier> for <candidate>. Origin's existing tag is used
when there is one. Otherwise the tier's certifications run, and the release
commit is written and pushed with a new tag. Fails when a certification
fails or the push does.

Usage: __releases__attempt__record <candidate> <version> <tier> <top>
FUN
__releases__attempt__record() {
  __releases__attempt__record__earned="$(releases__attempt__earned "$1" "$3")" || return 1
  if @defined "$__releases__attempt__record__earned"; then
    __releases__attempt__already "$3" "$__releases__attempt__record__earned"
    return 0
  fi

  __releases__attempt__record__name="$(versions__format__tag_name "$2" "$3")" || return 1
  __releases__attempt__prove "$1" "$3" "$__releases__attempt__record__name" || return 1

  __releases__attempt__land "$1" "$3" "$__releases__attempt__record__name" "$4"
}

: <<'FUN'
Promotes the tag <name> to every site of <tier>. Prints nothing. Fails
when a site refuses the tag.
FUN
__releases__attempt__promote() {
  releases__release_promote "$2" >&2 || {
    error "attempt: ${2} could not be promoted to the ${1} sites, so the attempt stops here."
    return 1
  }
}

: <<'FUN'
Prints <name>, the tag origin already has for <tier>, and logs it.
FUN
__releases__attempt__already() {
  log "Attempt: ${1} is earned already, by ${2}."
  println "$2"
}

: <<'FUN'
Runs the certifications of <tier> on <candidate>, for the tag <name>.
Fails when one of them fails.
FUN
__releases__attempt__prove() {
  releases__release_candidate "$1" "$3" || {
    error "attempt: ${2} is red; ${1} is not proven as ${3}, and the attempt stops here."
    return 1
  }
}

: <<'FUN'
Writes the release commit of <candidate> for <tier> and pushes it to
origin with the tag <name>. When <top> is true, the same push moves the
certified branch. Prints the tag. When origin rejects the push,
__releases__attempt__lost decides the result.
FUN
__releases__attempt__land() {
  __releases__attempt__land__record="$(releases__record__write "$1" "$3")" || return 1
  __releases__attempt__land__writes="$(__releases__attempt__writes "$__releases__attempt__land__record" "$4")" || return 1
  __releases__attempt__land__landed="$(releases__record__publish \
    "$__releases__attempt__REMOTE" \
    "$__releases__attempt__land__record" \
    "$__releases__attempt__land__writes"
  )" || return 1
  if @is_true "$__releases__attempt__land__landed"; then
    log "Attempt: ${2} earned by ${3}."
    println "$3"
    return 0
  fi
  __releases__attempt__lost "$1" "$2" "$3"
}

: <<'FUN'
Prints the extra ref updates to push with <record>'s tag: the move of the
certified branch when <top> is true, and none otherwise.
FUN
__releases__attempt__writes() {
  if @is_true "$2"; then
    __releases__attempt__writes__certified="$(releases__certified__write "$1")" || return 1
    @arr __releases__attempt__writes__out "$__releases__attempt__writes__certified"
    println "$__releases__attempt__writes__out"
    return 0
  fi
  @arr __releases__attempt__writes__out
  println "$__releases__attempt__writes__out"
}

: <<'FUN'
Handles a push of the tag <name> that origin rejected because the tag
exists. Deletes the local tag and fetches origin's. Prints origin's tag
when it is for <candidate>, and fails when it is for another commit.
FUN
__releases__attempt__lost() {
  git__tag_delete "$3"
  git__remotes__fetch_tags "$__releases__attempt__REMOTE" || return 1
  __releases__attempt__lost__earned="$(releases__attempt__earned "$1" "$2")" || return 1
  if @defined "$__releases__attempt__lost__earned"; then
    log "Attempt: ${2} was earned by another run of this attempt, ${__releases__attempt__lost__earned}."
    println "$__releases__attempt__lost__earned"
    return 0
  fi
  error "attempt: origin refused ${3}; another attempt earned the name on a different candidate, so this one stops at ${2}."
  return 1
}

: <<'PUB_FUN'
Prints the local tag of <tier> for <candidate>, or nothing when there is
none. Fetch origin's tags first to read origin's state.

  releases__attempt__earned 9a02... rc  ->  0.67.0-1.rc
  releases__attempt__earned 9a02... rc  ->  (nothing)

Usage: releases__attempt__earned <candidate> <tier>
PUB_FUN
releases__attempt__earned() {
  __releases__attempt__earned__tags="$(git__tags)" || return 1
  @arr __releases__attempt__earned__arr_12
  @reduce __releases__attempt__earned__records __releases__attempt__pick_record "$__releases__attempt__earned__tags" "$__releases__attempt__earned__arr_12" "$1" "$2"
  if @empty "$__releases__attempt__earned__records"; then
    printf '\n'
    return 0
  fi
  @get __releases__attempt__earned__out "$__releases__attempt__earned__records" '.[0]'
  println "$__releases__attempt__earned__out"
}

: <<'FUN'
@reduce callback. Prints <acc> with <tag> added when it is the tag of
<tier> for <candidate>, and unchanged otherwise.
  $1 acc   $2 tag   $3 candidate   $4 tier
FUN
__releases__attempt__pick_record() {
  @unwrap __releases__attempt__pick_record__tag "$2"
  if @is_true "$(__releases__attempt__is_record_of "$__releases__attempt__pick_record__tag" "$3" "$4")"; then
    @push __releases__attempt__pick_record__out "$1" "$__releases__attempt__pick_record__tag"
    println "$__releases__attempt__pick_record__out"
    return 0
  fi
  println "$1"
}

: <<'FUN'
Prints true when <tag> is the tag of <tier> for <candidate>: its name is a
version on that tier, it points at a release commit, and that commit's
parent is the candidate. Prints false otherwise.
FUN
__releases__attempt__is_record_of() {
  __releases__attempt__is_record_of__parsed="$(versions__parse_version "$1" 2>/dev/null)" || {
    @false __releases__attempt__is_record_of__out
    println "$__releases__attempt__is_record_of__out"
    return 0
  }
  if @get __releases__attempt__is_record_of__get_13 "$__releases__attempt__is_record_of__parsed" '.pre_type' ''; [ "$__releases__attempt__is_record_of__get_13" != "$3" ]; then
    @false __releases__attempt__is_record_of__out
    println "$__releases__attempt__is_record_of__out"
    return 0
  fi
  if [ "$(releases__record__at "$1" 2>/dev/null)" != "$1" ]; then
    @false __releases__attempt__is_record_of__out
    println "$__releases__attempt__is_record_of__out"
    return 0
  fi
  if [ "$(git__commits__parent_of "$1" 2>/dev/null)" != "$2" ]; then
    @false __releases__attempt__is_record_of__out
    println "$__releases__attempt__is_record_of__out"
    return 0
  fi
  @true __releases__attempt__is_record_of__out
  println "$__releases__attempt__is_record_of__out"
}
