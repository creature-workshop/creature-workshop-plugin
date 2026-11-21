#!/bin/sh

: <<'MODULE'
Release names, and the git tags that carry them.

A release name is a version, the three numbers, followed for a prerelease
by a hyphen and a part spelling its certification and, on a tag, its
count. How that part is spelled is a version format, a plugin of the kind
lib/versions/_format.sh declares; two are here:

  increment   1.2.0-rc.3    the tier, then a count of its own
  counter     1.2.0-3.rc    one counter per version, then the tier, and
                            the tier alone, 1.2.0-dev, on the trunk
                            (ADR.17@global)

Every reader takes every format's names, since a repository's history
keeps its older tags for good; a plan writes the format the repository's
manifest declares under version-format. Two names of one version rank,
here and in every reader of tags, a clean version above every prerelease,
and prereleases by the key their format gives each part, the format's
precedence first: one format's names rank above the other's as a block, as
semver ranks a word above a number, and within a format as the format
says.

POSIX sh-clean (no local/[[ ]]/(( ))/arrays): the file may be sourced into the
POSIX-targeted interpreter/emit path. Structured data (parsed versions, the
prerelease-precedence ladder) is expressed through the structs API rather than
bash associative arrays, so the backend stays swappable.
MODULE

import \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/git/tags.sh" \
  "$SHELLOPS_DIR/lib/versions/_format.sh"

: <<'PUB_CONST'
The level a version bump or a release is: which of the three numbers moves.
Public: versions__get_release_type answers one, and bump ranks and infers them.
PUB_CONST
@enum versions__LEVEL PATCH MINOR MAJOR

: <<'PUB_CONST'
The tiers a prerelease is certified to, from the least confident up, each
member's word being the one its tags carry. A version on a later tier
outranks one on an earlier, whatever the increments, and a clean version
outranks them all; every ranking in this module reads the order here.
Public: the tag words and their order are this module's to declare, and a
reader of tags takes them from here.
PUB_CONST
@enum versions__TIER DEV ALPHA BETA RC

# CONST: What a clean version's empty part sorts by where a format's key would be; the cleanness field before it already ranks the clean version above every prerelease.
__versions__CLEAN_ORDER="0.0000000000.0000000000"

# CONST: The word for a clean version where a tier is asked for, above every tier.
__versions__STABLE="stable"

: <<'PUB_FUN'
Parses a release name into a version struct on stdout.

Read fields with @get:

  ver="$(versions__parse_version "1.2.3-alpha.4")"
  @get "$ver" '.major'      # 1
  @get "$ver" '.minor'      # 2
  @get "$ver" '.patch'      # 3
  @get "$ver" '.pre_type'   # alpha, the tier
  @get "$ver" '.pre_inc'    # 4, the count
  @get "$ver" '.format'     # increment, the format the part is written in

The tier and the count are read by the part's format, and the struct
carries the format's name, so a planner knows whether a count is the
name's to move or the tags' to hand out; a clean version carries none:

  versions__parse_version "1.2.3-4.alpha"  ->  {..., "pre_type": "alpha", "pre_inc": "4", "format": "counter"}
  versions__parse_version "1.2.3-dev"      ->  {..., "pre_type": "dev", "pre_inc": "", "format": "counter"}
  versions__parse_version "v1.2.3"         ->  {"major": "1", ..., "pre_type": "", "pre_inc": "", "format": ""}

Warns and returns non-zero when the input is not a release name.
PUB_FUN
versions__parse_version() {
  if ! versions__is_valid_semver "$1"; then
    warn "'$1' is not a valid semver version for this project"
    return 1
  fi

  __versions__parse_version__rest="$(versions__bare_version "$1")"
  __versions__parse_version__major="${__versions__parse_version__rest%%.*}"
  __versions__parse_version__rest="${__versions__parse_version__rest#*.}"
  __versions__parse_version__minor="${__versions__parse_version__rest%%.*}"
  __versions__parse_version__rest="${__versions__parse_version__rest#*.}"
  __versions__parse_version__patch="${__versions__parse_version__rest%%-*}"

  __versions__parse_version__pre_type=""
  __versions__parse_version__pre_inc=""
  __versions__parse_version__format=""
  case "$__versions__parse_version__rest" in
    *-*)
      __versions__parse_version__pre="${__versions__parse_version__rest#*-}"
      __versions__parse_version__format="$(versions__format_of "$__versions__parse_version__pre")"
      __versions__parse_version__pre_type="$(versions__format__call "$__versions__parse_version__format" tier "$__versions__parse_version__pre")"
      __versions__parse_version__pre_inc="$(versions__format__call "$__versions__parse_version__format" count "$__versions__parse_version__pre")"
      ;;
  esac

  @obj __versions__parse_version__out \
    '.major' "$__versions__parse_version__major" \
    '.minor' "$__versions__parse_version__minor" \
    '.patch' "$__versions__parse_version__patch" \
    '.pre_type' "$__versions__parse_version__pre_type" \
    '.pre_inc' "$__versions__parse_version__pre_inc" \
    '.format' "$__versions__parse_version__format"
  println "$__versions__parse_version__out"
}

: <<'PUB_FUN'
Prints the part of a parsed version after its version and the hyphen, in
the format the struct names, and nothing for a clean version: what
versions__parse_version read, spelled back.

  versions__prerelease_part <1.2.3-4.alpha>  ->  4.alpha
  versions__prerelease_part <1.2.3>          ->  (nothing)
PUB_FUN
versions__prerelease_part() {
  @let "$1" __versions__prerelease_part__ pre_type pre_inc format
  if @defined "$__versions__prerelease_part__format"; then
    versions__format__call "$__versions__prerelease_part__format" name \
      "$__versions__prerelease_part__pre_type" \
      "$__versions__prerelease_part__pre_inc"
  else
    printf '\n'
  fi
  @unlet __versions__prerelease_part__ pre_type pre_inc format
}

: <<'PUB_FUN'
Prints the parsed version <parsed> with its prerelease part replaced by
<pre>, read by <pre>'s format, or made clean by an empty <pre>: how a plan
moves a version to the part a format hands it. Fails naming <pre> when no
format reads it.

  versions__with_prerelease <1.2.3-dev.4> 5.rc  ->  {..., "pre_type": "rc", "pre_inc": "5", "format": "counter"}
  versions__with_prerelease <1.2.3-dev.4> ""    ->  {..., "pre_type": "", "pre_inc": "", "format": ""}
PUB_FUN
versions__with_prerelease() {
  if ! @defined "$2"; then
    @set __versions__with_prerelease__out "$1" '.pre_type' "" '.pre_inc' "" '.format' ""
    println "$__versions__with_prerelease__out"
    return 0
  fi

  __versions__with_prerelease__format="$(versions__format_of "$2")" || return 1
  @set __versions__with_prerelease__out "$1" \
    '.pre_type' "$(versions__format__call "$__versions__with_prerelease__format" tier "$2")" \
    '.pre_inc' "$(versions__format__call "$__versions__with_prerelease__format" count "$2")" \
    '.format' "$__versions__with_prerelease__format"
  println "$__versions__with_prerelease__out"
}

: <<'PUB_FUN'
Prints the release name a parsed version spells: the three numbers, then
for a prerelease the hyphen and the part in the format the struct names.

  versions__format_version <1.2.3-4.alpha>  ->  1.2.3-4.alpha
  versions__format_version <1.2.3>          ->  1.2.3
PUB_FUN
versions__format_version() {
  @let "$1" __versions__format_version__ major minor patch
  __versions__format_version__pre="$(versions__prerelease_part "$1")"
  printf '%s.%s.%s%s\n' \
    "$__versions__format_version__major" \
    "$__versions__format_version__minor" \
    "$__versions__format_version__patch" \
    "${__versions__format_version__pre:+-$__versions__format_version__pre}"
  @unlet __versions__format_version__ major minor patch
}

: <<'PUB_FUN'
Succeeds quietly when <word> can name a tier, letters alone, and fails
quietly otherwise: the spelling every format holds a tier to, held here
once. A word that names none of the tiers is still a tier word, since a
tag may carry one, and ranks with dev.

  versions__is_tier_word rc   ->  0
  versions__is_tier_word rc1  ->  1
PUB_FUN
versions__is_tier_word() {
  # structs-lint: allow -- the tier grammar itself, the one place it is spelled; every format reads by it
  case "$1" in
    ''|*[!a-zA-Z]*) return 1 ;;
  esac
  return 0
}

: <<'PUB_FUN'
Prints the tier words space-joined in certification order, dev first: what
an awk program ranking tiers takes as its tiers variable
(lib/versions/tier_rank.awk).

  versions__tier_words  ->  dev alpha beta rc
PUB_FUN
versions__tier_words() {
  @enum_values __versions__tier_words__enum_values_1 versions__TIER
  @join __versions__tier_words__out "$__versions__tier_words__enum_values_1" ' '
  println "$__versions__tier_words__out"
}

: <<'PUB_FUN'
Prints the rank of a tier: its place among the tiers, dev ranking 0. A word
that names no tier ranks with dev.

  versions__tier_rank beta  ->  2
PUB_FUN
versions__tier_rank() {
  if ! versions__TIER_is "$1"; then
    printf '0\n'
    return 0
  fi

  @enum_rank __versions__tier_rank__out versions__TIER "$1"
  println "$__versions__tier_rank__out"
}

: <<'PUB_FUN'
Checks whether the provided string is a release name: a version, optionally
led by the v of a tag, optionally followed by a hyphen and a prerelease
part some format reads. Succeeds and fails quietly.

  versions__is_valid_semver 1.2.0-rc.3  ->  0
  versions__is_valid_semver 1.2.0-3.rc  ->  0
  versions__is_valid_semver v1.2.0-dev  ->  0
  versions__is_valid_semver 1.2.0-3     ->  1
PUB_FUN
versions__is_valid_semver() {
  __versions__is_valid_semver__bare="${1#v}"
  __versions__is_valid_semver__version="${__versions__is_valid_semver__bare%%-*}"
  __versions__is_version_numbers "$__versions__is_valid_semver__version" || return 1

  case "$__versions__is_valid_semver__bare" in
    *-*) __versions__format_of "${__versions__is_valid_semver__bare#*-}" ;;
    *) return 0 ;;
  esac
}

: <<'FUN'
Succeeds quietly when <version> is three integers joined by dots, and fails
quietly otherwise.
FUN
__versions__is_version_numbers() {
  case "$1" in
    *.*.*.*) return 1 ;;
    *.*.*) ;;
    *) return 1 ;;
  esac

  __versions__is_version_numbers__rest="${1#*.}"
  @is_int "${1%%.*}" \
    && @is_int "${__versions__is_version_numbers__rest%%.*}" \
    && @is_int "${__versions__is_version_numbers__rest#*.}"
}

: <<'PUB_FUN'
Prints the version a release name carries, the three numbers alone, in
either tag form. Fails naming the string when it is not a release name.

  versions__version_of 1.2.0-3.rc  ->  1.2.0
  versions__version_of v1.2.0-dev  ->  1.2.0
PUB_FUN
versions__version_of() {
  versions__version_assert "$1" || return 1

  __versions__version_of__bare="$(versions__bare_version "$1")"
  println "${__versions__version_of__bare%%-*}"
}

: <<'PUB_FUN'
Checks that VERSION is one this module can compare, and reports it when it is
not: the error names the offending string, and CONSEQUENCE, when given, says
what the caller will not do about it.

Returns 1 rather than exiting, so the caller decides what a bad version costs.

  versions__version_assert "3.1.0" "refusing to cut it."   # -> 0, silent
  versions__version_assert "nightly" "refusing to cut it."
  # -> 1, and on stderr:
  #    'nightly' is not a version this project can compare; refusing to cut it.
PUB_FUN
versions__version_assert() {
  if versions__is_valid_semver "$1"; then
    return 0
  fi

  error "'$1' is not a version this project can compare${2:+; $2}"
  return 1
}

: <<'PUB_FUN'
Prints the version a tag name carries, whichever form the tag takes: the
repository may write its tags bare or v-prefixed, and the version is the same
either way.

  versions__bare_version "v3.1.0"  ->  3.1.0
  versions__bare_version "3.1.0"   ->  3.1.0
PUB_FUN
versions__bare_version() {
  println "${1#v}"
}

: <<'PUB_FUN'
Checks whether or not the semver version passed is a release version

Example:
- 1.0.0 -> true
- 0.4.2 -> true
- 12.20.0-alpha.1 -> false
- 1.0.0-rc.20 -> false
PUB_FUN
versions__is_release_version() {
    __versions__is_release_version__parsed="$(versions__parse_version "$1")" || @obj __versions__is_release_version__parsed
  @get __versions__is_release_version__pre_type "$__versions__is_release_version__parsed" '.pre_type' ''
  ! @defined "$__versions__is_release_version__pre_type"
}

: <<'PUB_FUN'
Gets the type of release this version represents

Example:
- 1.0.0 -> major
- 1.4.0 -> minor
- 1.4.2 -> patch
- 1.4.3-dev.1 -> dev
- 1.4.3-alpha.1 -> alpha
- etc
PUB_FUN
versions__get_release_type() {
    __versions__get_release_type__parsed="$(versions__parse_version "$1")" || @obj __versions__get_release_type__parsed

  @let "$__versions__get_release_type__parsed" __versions__get_release_type__ pre_type patch minor
  @defined "$__versions__get_release_type__patch" || __versions__get_release_type__patch=0
  @defined "$__versions__get_release_type__minor" || __versions__get_release_type__minor=0

  if @defined "$__versions__get_release_type__pre_type"; then
    echo "$__versions__get_release_type__pre_type"
    return
  fi

  if [ "$__versions__get_release_type__patch" -gt 0 ]; then
    println "$versions__LEVEL_PATCH"
  elif [ "$__versions__get_release_type__minor" -gt 0 ]; then
    println "$versions__LEVEL_MINOR"
  else
    println "$versions__LEVEL_MAJOR"
  fi
  @unlet __versions__get_release_type__ pre_type patch minor
}

: <<'PUB_FUN'
Returns 0 if the version's prerelease channel is at or above the given
threshold, or if the version is a stable release. Returns 1 otherwise. A
threshold of stable is met by a stable release alone.

Channels ordered: dev(0) < alpha(1) < beta(2) < rc(3) < stable.

Usage:
  versions__version_meets_confidence "1.0.0-beta.1" "beta"   # -> 0 (true)
  versions__version_meets_confidence "1.0.0-alpha.2" "beta"   # -> 1 (false)
  versions__version_meets_confidence "1.0.0" "beta"            # -> 0 (true, stable)
  versions__version_meets_confidence "1.0.0-6.rc" "stable"     # -> 1 (false)
PUB_FUN
versions__version_meets_confidence() {
  __versions__version_meets_confidence__parsed="$(versions__parse_version "$1")" || return 1

  @get __versions__version_meets_confidence__pre_type "$__versions__version_meets_confidence__parsed" '.pre_type' ''
  if ! @defined "$__versions__version_meets_confidence__pre_type"; then
    return 0
  fi
  if [ "$2" = "$__versions__STABLE" ]; then
    return 1
  fi

  [ "$(versions__tier_rank "$__versions__version_meets_confidence__pre_type")" \
    -ge "$(versions__tier_rank "$2")" ]
}

: <<'PUB_FUN'
  Compares two release names, by the three numbers and then as the module
  doc ranks the prerelease parts of one version:
    - dev.1 < dev.2 < alpha.1 < rc.1        the increment format, by tier then count
    - 3.alpha < 4.dev < 5.beta              the counter format, by counter alone
    - 9.rc < dev < dev.1 < (clean)          a tier alone above every counter tag

  Returns: -1 if left > right, 1 if left < right, 0 if equal.
PUB_FUN
versions__compare_versions() {
  if [ -z "$1" ] && [ -n "$2" ]; then
    println 1
    return
  elif [ -n "$1" ] && [ -z "$2" ]; then
    println -1
    return
  elif [ -z "$1" ] && [ -z "$2" ]; then
    println 0
    return
  fi

  __versions__compare_versions__left="$(versions__parse_version "$1")"
  __versions__compare_versions__right="$(versions__parse_version "$2")"

  # Both sides carry the same three fields under the one prefix a binding
  # may take, so each side is read out under its own name before the next.
  @let "$__versions__compare_versions__left" __versions__compare_versions__ major minor patch
  __versions__compare_versions__left_major="$__versions__compare_versions__major"
  __versions__compare_versions__left_minor="$__versions__compare_versions__minor"
  __versions__compare_versions__left_patch="$__versions__compare_versions__patch"
  @unlet __versions__compare_versions__ major minor patch

  @let "$__versions__compare_versions__right" __versions__compare_versions__ major minor patch
  __versions__compare_versions__right_major="$__versions__compare_versions__major"
  __versions__compare_versions__right_minor="$__versions__compare_versions__minor"
  __versions__compare_versions__right_patch="$__versions__compare_versions__patch"
  @unlet __versions__compare_versions__ major minor patch

  __versions__compare_versions__result="$(__versions__compare_components \
    "$__versions__compare_versions__left_major" \
    "$__versions__compare_versions__right_major")"
  if [ "$__versions__compare_versions__result" -ne 0 ]; then
    println "$__versions__compare_versions__result"
    return
  fi

  __versions__compare_versions__result="$(__versions__compare_components \
    "$__versions__compare_versions__left_minor" \
    "$__versions__compare_versions__right_minor")"
  if [ "$__versions__compare_versions__result" -ne 0 ]; then
    println "$__versions__compare_versions__result"
    return
  fi

  __versions__compare_versions__result="$(__versions__compare_components \
    "$__versions__compare_versions__left_patch" \
    "$__versions__compare_versions__right_patch")"
  if [ "$__versions__compare_versions__result" -ne 0 ]; then
    println "$__versions__compare_versions__result"
    return
  fi

  __versions__compare_prerelease "$1" "$2"
}

: <<'PUB_FUN'
Prints true when LEFT is a newer version than RIGHT, false when it is the same
version or an older one. Prerelease precedence counts, as it does for
versions__compare_versions.

  versions__version_is_newer "3.0.0-dev.34" "3.0.0-dev.33"  ->  true
  versions__version_is_newer "3.0.0-dev.33" "3.0.0-dev.34"  ->  false
  versions__version_is_newer "3.0.0" "3.0.0"                ->  false
PUB_FUN
versions__version_is_newer() {
  __versions__version_is_newer__order="$(versions__compare_versions "$1" "$2")"
  @equals __versions__version_is_newer__out "$__versions__version_is_newer__order" "$(@int -1)"
  println "$__versions__version_is_newer__out"
}

: <<'FUN'
Compares two integers as versions__compare_versions reports: -1 when the
left is the greater, 1 when the right is, 0 when they are equal.
FUN
__versions__compare_components() {
  if [ "$1" -gt "$2" ]; then
    println -1
  elif [ "$1" -lt "$2" ]; then
    println 1
  else
    println 0
  fi
}

: <<'FUN'
Compares the prerelease parts of two release names of one version, as
versions__compare_versions reports: a clean version above a prerelease, two
clean ones level, and two prereleases by the key each part's format gives
it.
FUN
__versions__compare_prerelease() {
  __versions__compare_prerelease__result="$(__versions__compare_components \
    "$(__versions__is_clean "$1")" \
    "$(__versions__is_clean "$2")")"
  if [ "$__versions__compare_prerelease__result" -ne 0 ] || [ "$(__versions__is_clean "$1")" -eq 1 ]; then
    println "$__versions__compare_prerelease__result"
    return
  fi

  __versions__compare_keys \
    "$(__versions__order_key "$1")" \
    "$(__versions__order_key "$2")"
}

: <<'FUN'
Prints 1 for a release name that is a clean version and 0 for a
prerelease, so the two compare as numbers and sort in byte order.
FUN
__versions__is_clean() {
  case "${1#v}" in
    *-*) printf '0\n' ;;
    *) printf '1\n' ;;
  esac
}

: <<'FUN'
Prints the key ranking the release name <name> among the prereleases of
its version, in the form the format role @order prints, what its format
gives its part; a clean version's empty part takes __versions__CLEAN_ORDER.

  __versions__order_key 1.2.0-beta.2  ->  1.0000000002.0000000002
  __versions__order_key 1.2.0         ->  0.0000000000.0000000000
FUN
__versions__order_key() {
  __versions__order_key__bare="${1#v}"
  case "$__versions__order_key__bare" in
    *-*)
      __versions__order_key__pre="${__versions__order_key__bare#*-}"
      __versions__format_of "$__versions__order_key__pre" || return 1
      println "$__versions__order_key__pre" \
        | versions__format__call "$__versions__format_of__format" order
      ;;
    *)
      println "$__versions__CLEAN_ORDER"
      ;;
  esac
}

: <<'FUN'
Compares two order keys field by field, as versions__compare_versions
reports: -1 when the left ranks higher, 1 when the right does, 0 when they
are level.
FUN
__versions__compare_keys() {
  __versions__compare_keys__left="$1"
  __versions__compare_keys__right="$2"
  __versions__compare_keys__result=0
  while [ "$__versions__compare_keys__result" -eq 0 ] && @defined "$__versions__compare_keys__left"; do
    __versions__compare_keys__result="$(__versions__compare_components \
      "${__versions__compare_keys__left%%.*}" \
      "${__versions__compare_keys__right%%.*}")"
    __versions__compare_keys__left="$(__versions__after_field "$__versions__compare_keys__left")"
    __versions__compare_keys__right="$(__versions__after_field "$__versions__compare_keys__right")"
  done

  println "$__versions__compare_keys__result"
}

: <<'FUN'
Prints the key <key> past its first dot-separated field, and nothing when
the field is its last.
FUN
__versions__after_field() {
  case "$1" in
    *.*) println "${1#*.}" ;;
    *) printf '\n' ;;
  esac
}

: <<'PUB_FUN'
Prints the newest version any tag in the repository records, prerelease or
release, whichever form the tag takes; 0.0.0 when no tag records a version.

Every tag counts, wherever its commit sits. A release above dev is recorded
on a commit off the trunk (ADR 000044), so a reader that walked the trunk's
ancestry would never see it and would plan the next dev of a version that
already shipped stable. Two tags of one version rank as
versions__compare_versions ranks them, so an alpha outranks every dev of its
version in the increment format, the counter alone ranks the counter
format, and the clean version outranks them all.

  versions__latest_version  ->  1.2.0-rc.1   (tags 1.2.0-dev.9 on the trunk, 1.2.0-rc.1 on a record)
PUB_FUN
versions__latest_version() {
  __versions__latest_version__newest="$(__versions__tags_desc | head -1)"
  if ! @defined "$__versions__latest_version__newest"; then
    printf '0.0.0\n'
    return 0
  fi

  versions__bare_version "$__versions__latest_version__newest"
}

: <<'FUN'
Prints the repository's version tags newest first, as this module ranks
them, each as the repository wrote it; nothing when it holds none. A tag
naming a tool or a nightly is not a version and is left out. Each tag is
given a sort key that byte order sorts the way versions__compare_versions
ranks, so the tags are ranked in one sort.

  __versions__tags_desc  ->  1.2.0, 1.2.0-dev.9, v1.2.0-3.rc, 1.1.0, ...
FUN
__versions__tags_desc() {
  git tag -l \
    | __versions__keyed_tags \
    | LC_ALL=C sort -r \
    | cut -f2
}

: <<'FUN'
Prints each version tag on stdin as its sort key, a tab and the tag, and
passes over a tag that is not a release name. The clean versions are keyed
here and each format's prereleases by that format's @order in one call, so
the tags cost a few processes and not one each
(lib/versions/sort_key.awk).

  println 1.2.0 nightly | __versions__keyed_tags  ->  0000000001.0000000002.0000000000.1.0.0000000000.0000000000<TAB>1.2.0
FUN
__versions__keyed_tags() {
  __versions__keyed_tags__dir="$(mktemp -d)"
  cat > "$__versions__keyed_tags__dir/tags"

  {
    __versions__clean_tags < "$__versions__keyed_tags__dir/tags"
    for __versions__keyed_tags__format in $__versions__format__NAMES; do
      __versions__format_tags "$__versions__keyed_tags__format" "$__versions__keyed_tags__dir" \
        < "$__versions__keyed_tags__dir/tags"
    done
  } | awk -f "$SHELLOPS_DIR/lib/versions/sort_key.awk"

  rm -rf "$__versions__keyed_tags__dir"
}

: <<'FUN'
Prints each clean version tag on stdin as the tag, a tab and
__versions__CLEAN_ORDER, the form lib/versions/sort_key.awk reads.
FUN
__versions__clean_tags() {
  while IFS= read -r __versions__clean_tags__tag; do
    case "${__versions__clean_tags__tag#v}" in
      *-*) continue ;;
    esac
    __versions__is_version_numbers "${__versions__clean_tags__tag#v}" || continue
    printf '%s\t%s\n' "$__versions__clean_tags__tag" "$__versions__CLEAN_ORDER"
  done
}

: <<'FUN'
Prints each tag on stdin whose part the format <format> reads as the tag, a
tab and the key the format gives the part, the form
lib/versions/sort_key.awk reads, keying every part in one call of the
format's @order; <dir> holds the files the call pairs.
FUN
__versions__format_tags() {
  : > "$2/parts"
  : > "$2/names"
  while IFS= read -r __versions__format_tags__tag; do
    __versions__format_tags__bare="${__versions__format_tags__tag#v}"
    case "$__versions__format_tags__bare" in
      *-*) ;;
      *) continue ;;
    esac
    __versions__is_version_numbers "${__versions__format_tags__bare%%-*}" || continue
    versions__format__call "$1" is "${__versions__format_tags__bare#*-}" || continue
    println "${__versions__format_tags__bare#*-}" >> "$2/parts"
    println "$__versions__format_tags__tag" >> "$2/names"
  done

  versions__format__call "$1" order < "$2/parts" > "$2/keys"
  paste "$2/names" "$2/keys"
}

: <<'PUB_FUN'
  Prints the name of the tag that records VERSION, in whichever form the
  repository wrote it: the bare version first, then the v-prefixed one, so a
  repository that has moved from one form to the other resolves either way.
  Empty when neither exists, and empty for anything that is not a version:
  a tag naming a tool or a nightly is not a release, whatever it is called.

  Usage: versions__tag_for_version "0.8.0"  # -> "v0.8.0" where the repository tags with the prefix
PUB_FUN
versions__tag_for_version() {
  versions__is_valid_semver "$1" || return 0

  if git rev-parse -q --verify "refs/tags/$1" >/dev/null 2>&1; then
    println "$1"
    return 0
  fi
  if git rev-parse -q --verify "refs/tags/v$1" >/dev/null 2>&1; then
    printf 'v%s\n' "$1"
    return 0
  fi

  return 0
}

: <<'PUB_FUN'
  Prints true when a tag spelled exactly NAME is in the repository, false
  otherwise. The name is asked about as written, so a caller that cares which
  spelling is taken gets that answer rather than versions__tag_for_version's, which
  reports whichever spelling records a version.

  Usage: versions__tag_exists "v0.8.0"  # -> true
PUB_FUN
versions__tag_exists() {
  @succeeds __versions__tag_exists__out git show-ref --verify --quiet "refs/tags/$1"
  println "$__versions__tag_exists__out"
}

: <<'PUB_FUN'
Prints the first version tag on the commit <ref> names, in whichever form the
repository wrote it, or nothing when that commit carries none. Asks the tags
on the commit itself, not the newest in the repository: a release recorded
off the trunk is newer and is not what <ref> is tagged with. Non-zero when
<ref> resolves to no commit.

  versions__tag_at HEAD  ->  1.2.0-dev.9

Usage: versions__tag_at <ref>
PUB_FUN
versions__tag_at() {
  __versions__tag_at__tags="$(git__tags_at "$1")" || return 1
  @find __versions__tag_at__found __versions__tag_at__is_version "$__versions__tag_at__tags"
  if @null __versions__tag_at__null_2; [ "$__versions__tag_at__found" = "$__versions__tag_at__null_2" ]; then
    return 0
  fi

  @unwrap __versions__tag_at__out "$__versions__tag_at__found"
  println "$__versions__tag_at__out"
}

: <<'FUN'
@find callback: whether the wrapped tag $1 names a version.
FUN
__versions__tag_at__is_version() {
  @unwrap __versions__tag_at__is_version__unwrap_3 "$1"
  versions__is_valid_semver "$__versions__tag_at__is_version__unwrap_3"
}

: <<'PUB_FUN'
Prints the nearest version tag HEAD reaches, in whichever form the repository
wrote it, or nothing when HEAD reaches none.

This walks ancestry on purpose. On the trunk the tags reachable are the dev
tags on its landings, and a release above dev sits on a record off the trunk
(ADR 000044); so from the trunk this is the last release cut from it, which is
what bounds a "since the last release" window. For the newest version the
repository holds, ask versions__latest_version.

  versions__nearest_tag  ->  1.2.0-dev.9   (HEAD on the trunk, 1.2.0-rc.1 on a record off it)
PUB_FUN
versions__nearest_tag() {
  git describe --tags --abbrev=0 --match '[0-9]*' --match 'v[0-9]*' 2>/dev/null || true
}

: <<'PUB_FUN'
ISO-8601 timestamp of the nearest version tag HEAD reaches, whether the
repository wrote it bare or v-prefixed.

Echoes empty, and says so on stderr, when HEAD reaches no version tag, which
is the case with no tags at all, so a caller bounding a "since the last
release" window knows the window is open.

  versions__nearest_tag_date  ->  2026-06-17T12:40:00+00:00
PUB_FUN
versions__nearest_tag_date() {
  __versions__nearest_tag_date__tag="$(versions__nearest_tag)"
  if ! @defined "$__versions__nearest_tag_date__tag"; then
    log "HEAD reaches no version tag: no date to bound the window with"
    return 0
  fi

  git__tag_date "$__versions__nearest_tag_date__tag"
}

: <<'FUN'
  Prints the repository's version tags newest first as __versions__tags_desc
  ranks them, any leading 'v' stripped, so a repository that tags bare and
  one that tags v-prefixed read the same.

  Usage: __versions__versions_desc  # -> 1.2.0-dev.1, 1.1.0, 1.0.0, ...
FUN
__versions__versions_desc() {
  __versions__tags_desc | sed 's/^v//'
}

: <<'PUB_FUN'
  Gets the latest release version tag from git (no pre-release suffix), bare or
  v-prefixed. Matches 1.0.0 and v0.5.0 but not v1.0.0-alpha or 1.0.0-rc1.
  Returns the version without the 'v' prefix, or empty string if no release tags exist.
PUB_FUN
versions__latest_release_version() {
  __versions__versions_desc | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -1
}

: <<'PUB_FUN'
  Gets the latest pre-release version tag from git (has a - suffix), bare or
  v-prefixed. Matches 1.0.0-alpha, v1.0.0-rc1, 0.5.0-beta.1.
  Returns the version without the 'v' prefix, or empty string if no pre-release tags exist.
PUB_FUN
versions__latest_prerelease_version() {
  __versions__versions_desc | grep -E '^[0-9]+\.[0-9]+\.[0-9]+-' | head -1
}

: <<'PUB_FUN'
  Gets the latest 0.x.x release version tag from git (genesis/unfinished), bare
  or v-prefixed. Matches 0.0.1 and v0.5.0 but not 0.1.0-alpha.
  Returns the version without the 'v' prefix, or empty string if no 0.x.x release tags exist.
PUB_FUN
versions__latest_zero_version() {
  __versions__versions_desc | grep -E '^0\.[0-9]+\.[0-9]+$' | head -1
}

: <<'PUB_FUN'
Returns a JSON array of commit objects between two tags.
Each object contains {hash, message, review_number}.

Usage: versions__list_commits "v0.0.1-dev.1" "v0.0.1-dev.2"
PUB_FUN
versions__list_commits() {
  __versions__list_commits__begin="$1"
  __versions__list_commits__end="$2"

  __versions__list_commits__lines="$(git log --oneline --no-merges "${__versions__list_commits__begin}..${__versions__list_commits__end}")"
  if ! @defined "$__versions__list_commits__lines"; then
    @arr __versions__list_commits__out
    println "$__versions__list_commits__out"
    return
  fi

  # Pipe into the loop (no here-strings/process substitution) and echo the
  # accumulated array from inside the subshell so it reaches stdout.
  println "$__versions__list_commits__lines" | {
    @arr objects
    while IFS= read -r line; do
      hash="${line%% *}"
      message="${line#* }"
      review_number="$(__versions__extract_review_number "$message")"

      @push objects "$objects" "$(
        @obj \
          '.hash' "$hash" \
          '.message' "$message" \
          '.review_number' "$review_number"
      )"
    done
    println "$objects"
  }
}

:<<'FUN'
Extracts the first "#<n>" code-review reference from a commit message,
echoing the bare number. Echoes the JSON token "null" when none is present.
FUN
__versions__extract_review_number() {
  __versions__extract_review_number__match="$(printf '%s' "$1" | grep -oE '#[0-9]+' | head -n1)"
  if @defined "$__versions__extract_review_number__match"; then
    printf '%s' "${__versions__extract_review_number__match#\#}"
  else
    printf 'null'
  fi
}

: <<'PUB_FUN'
Finds the tag immediately before the given tag in git history.

Usage: versions__previous_tag "v0.0.1-dev.3"  # -> "v0.0.1-dev.2"
PUB_FUN
versions__previous_tag() {
  git describe --tags --abbrev=0 "${1:-HEAD}^" 2>/dev/null
}

: <<'PUB_FUN'
Finds the most recent tag in the same release channel as the given tag.

Channels group tags by their release type:
  - Prerelease (dev/alpha/beta/rc): same major.minor.patch and pre_type
  - Patch: same major.minor, release tags only
  - Minor: same major, release tags with patch == 0
  - Major: release tags with minor == 0 and patch == 0

Returns empty string when no previous channel tag exists.

Usage: versions__previous_channel_tag "v2.0.3"         # -> "v2.0.2"
       versions__previous_channel_tag "v3.0.1-dev.2"   # -> "v3.0.1-dev.1"
       versions__previous_channel_tag "v2.1.0"         # -> "v2.0.0"
PUB_FUN
versions__previous_channel_tag() {
  __versions__previous_channel_tag__current="$1"
  __versions__previous_channel_tag__stripped="${__versions__previous_channel_tag__current#v}"
  __versions__previous_channel_tag__parsed="$(versions__parse_version "$__versions__previous_channel_tag__stripped")"
  __versions__previous_channel_tag__type="$(versions__get_release_type "$__versions__previous_channel_tag__stripped")"

  __versions__tags_desc | {
    while IFS= read -r tag; do
      [ -z "$tag" ] && continue
      versions__is_valid_semver "$tag" || continue
      [ "$(versions__compare_versions "${tag#v}" "$__versions__previous_channel_tag__stripped")" = "1" ] || continue

      __versions__previous_channel_tag__same_channel="$(__versions__is_same_channel \
        "${tag#v}" "$__versions__previous_channel_tag__parsed" "$__versions__previous_channel_tag__type")" || return 1
      if @is_true "$__versions__previous_channel_tag__same_channel"; then
        println "$tag"
        break
      fi
    done
  }
}

: <<'PUB_FUN'
Tag to diff against when generating release notes.

For a stable release (no prerelease suffix), delegates to versions__previous_channel_tag.

For prerelease tags (dev/alpha/beta/rc), first returns the newest semver-older
tag in the same major.minor.patch target release, regardless of prerelease type.
This lets rc look back to beta/alpha, and later dev tags look back to earlier
dev tags.

When there is no older tag in the same target release (for example dev.1), it
falls back to the previous stable release in the channel that final release
would use (patch/minor/major).

Returns empty when no earlier release anchor exists.

Usage: versions__get_relevant_baseline_tag "v3.6.7-dev.9"  # -> v3.6.7-dev.8
       versions__get_relevant_baseline_tag "v3.6.7-dev.1"  # -> v3.6.6
       versions__get_relevant_baseline_tag "v4.0.0"        # -> v3.0.0
PUB_FUN
versions__get_relevant_baseline_tag() {
  __versions__get_relevant_baseline_tag__current="$1"
  __versions__get_relevant_baseline_tag__stripped="${__versions__get_relevant_baseline_tag__current#v}"
  __versions__get_relevant_baseline_tag__parsed="$(versions__parse_version "$__versions__get_relevant_baseline_tag__stripped")" || return 1

  if versions__is_release_version "$__versions__get_relevant_baseline_tag__stripped"; then
    versions__previous_channel_tag "$__versions__get_relevant_baseline_tag__current"
    return
  fi

  # Prefer same-channel baseline (e.g. alpha.1 for alpha.2), falling back
  # to cross-channel within the same target release (e.g. alpha.8 for rc.1
  # when no earlier rc exists).
  __versions__get_relevant_baseline_tag__same_channel="$(versions__previous_channel_tag "$__versions__get_relevant_baseline_tag__current")"
  if @defined "$__versions__get_relevant_baseline_tag__same_channel"; then
    println "$__versions__get_relevant_baseline_tag__same_channel"
    return
  fi

  __versions__get_relevant_baseline_tag__match="$(
    __versions__tags_desc | {
      while IFS= read -r tag; do
        [ -z "$tag" ] && continue
        versions__is_valid_semver "$tag" || continue
        [ "$(versions__compare_versions "${tag#v}" "$__versions__get_relevant_baseline_tag__stripped")" = "1" ] || continue
        __versions__get_relevant_baseline_tag__same_target="$(__versions__is_same_target_release \
          "${tag#v}" "$__versions__get_relevant_baseline_tag__parsed")" || return 1
        @is_true "$__versions__get_relevant_baseline_tag__same_target" || continue
        println "$tag"
        break
      done
    }
  )"
  if @defined "$__versions__get_relevant_baseline_tag__match"; then
    println "$__versions__get_relevant_baseline_tag__match"
    return
  fi

  @let "$__versions__get_relevant_baseline_tag__parsed" __versions__get_relevant_baseline_tag__ major minor patch
  versions__previous_channel_tag "v$__versions__get_relevant_baseline_tag__major.$__versions__get_relevant_baseline_tag__minor.$__versions__get_relevant_baseline_tag__patch"
  __versions__get_relevant_baseline_tag__status=$?
  @unlet __versions__get_relevant_baseline_tag__ major minor patch
  return "$__versions__get_relevant_baseline_tag__status"
}

: <<'PUB_FUN'
Returns the hash of the repository's initial commit.

Usage: versions__initial_commit  # -> "abc123..."
PUB_FUN
versions__initial_commit() {
  git rev-list --max-parents=0 HEAD
}

:<<'FUN'
Prints the struct boolean for whether <tag_version> belongs to the same channel
as <cur_struct>, per the release type (dev/alpha/beta/rc | patch | minor |
major). A channel this module does not know how to match answers false; a
<tag_version> versions__parse_version rejects fails.

Usage: if @is_true "$(__versions__is_same_channel "1.2.3" "$current" patch)"; then ... fi
FUN
__versions__is_same_channel() {
  __versions__is_same_channel__candidate="$(versions__parse_version "$1")" || return 1

  case "$3" in
    dev|alpha|beta|rc)
      __versions__same_prerelease_channel "$__versions__is_same_channel__candidate" "$2"
      ;;
    "$versions__LEVEL_PATCH")
      __versions__same_patch_channel "$__versions__is_same_channel__candidate" "$2"
      ;;
    "$versions__LEVEL_MINOR")
      __versions__same_minor_channel "$__versions__is_same_channel__candidate" "$2"
      ;;
    "$versions__LEVEL_MAJOR")
      __versions__same_major_channel "$__versions__is_same_channel__candidate" "$2"
      ;;
    *)
      @false __versions__is_same_channel__out
      println "$__versions__is_same_channel__out"
      ;;
  esac
}

: <<'FUN'
Prints the struct boolean for whether the parsed <candidate> shares <field> with
the parsed <current>; <default> stands in for a field either lacks.

Usage: __versions__same_field "$candidate" "$current" '.pre_type' ''
FUN
__versions__same_field() {
  @get __versions__same_field__get_4 "$1" "$3" "${4:-}"
  @get __versions__same_field__get_5 "$2" "$3" "${4:-}"
  @succeeds __versions__same_field__out [ "$__versions__same_field__get_4" = "$__versions__same_field__get_5" ]
  println "$__versions__same_field__out"
}

: <<'FUN'
Prints the struct boolean for whether the parsed <candidate> is a final release
(carries no pre_type).
FUN
__versions__is_final_release() {
  @get __versions__is_final_release__get_6 "$1" '.pre_type'
  @fails __versions__is_final_release__out @defined "$__versions__is_final_release__get_6"
  println "$__versions__is_final_release__out"
}

: <<'FUN'
Same major.minor.patch and the same pre_type: the prerelease series a
dev/alpha/beta/rc tag advances within.
FUN
__versions__same_prerelease_channel() {
  if @is_true "$(__versions__same_target_release "$1" "$2")" \
    && @is_true "$(__versions__same_field "$1" "$2" '.pre_type' '')"; then
    @true __versions__same_prerelease_channel__out
    println "$__versions__same_prerelease_channel__out"
  else
    @false __versions__same_prerelease_channel__out
    println "$__versions__same_prerelease_channel__out"
  fi
}

: <<'FUN'
A final release in the same major.minor: the series a patch tag advances.
FUN
__versions__same_patch_channel() {
  if @is_true "$(__versions__same_field "$1" "$2" '.major')" \
    && @is_true "$(__versions__same_field "$1" "$2" '.minor')" \
    && @is_true "$(__versions__is_final_release "$1")"; then
    @true __versions__same_patch_channel__out
    println "$__versions__same_patch_channel__out"
  else
    @false __versions__same_patch_channel__out
    println "$__versions__same_patch_channel__out"
  fi
}

: <<'FUN'
A final x.y.0 in the same major: the series a minor tag advances.
FUN
__versions__same_minor_channel() {
  if @get __versions__same_minor_channel__get_7 "$1" '.patch'; @is_true "$(__versions__same_field "$1" "$2" '.major')" \
    && [ "$__versions__same_minor_channel__get_7" = "0" ] \
    && @is_true "$(__versions__is_final_release "$1")"; then
    @true __versions__same_minor_channel__out
    println "$__versions__same_minor_channel__out"
  else
    @false __versions__same_minor_channel__out
    println "$__versions__same_minor_channel__out"
  fi
}

: <<'FUN'
A final x.0.0: the series a major tag advances.
FUN
__versions__same_major_channel() {
  @let "$1" __versions__same_major_channel__ minor patch
  if [ "$__versions__same_major_channel__minor" = "0" ] \
    && [ "$__versions__same_major_channel__patch" = "0" ] \
    && @is_true "$(__versions__is_final_release "$1")"; then
    @true __versions__same_major_channel__out
    println "$__versions__same_major_channel__out"
  else
    @false __versions__same_major_channel__out
    println "$__versions__same_major_channel__out"
  fi
  @unlet __versions__same_major_channel__ minor patch
}

: <<'FUN'
Prints the struct boolean for whether the parsed <candidate> targets the same
major.minor.patch as the parsed <current>.

Usage: __versions__same_target_release "$candidate" "$current"
FUN
__versions__same_target_release() {
  if @is_true "$(__versions__same_field "$1" "$2" '.major')" \
    && @is_true "$(__versions__same_field "$1" "$2" '.minor')" \
    && @is_true "$(__versions__same_field "$1" "$2" '.patch')"; then
    @true __versions__same_target_release__out
    println "$__versions__same_target_release__out"
  else
    @false __versions__same_target_release__out
    println "$__versions__same_target_release__out"
  fi
}

: <<'FUN'
Prints the struct boolean for whether <tag_version> targets the same
major.minor.patch as the parsed <cur_struct>; fails on a <tag_version>
versions__parse_version rejects.

Usage: if @is_true "$(__versions__is_same_target_release "1.2.3" "$current")"; then ... fi
FUN
__versions__is_same_target_release() {
  __versions__is_same_target_release__candidate="$(versions__parse_version "$1")" || return 1
  __versions__same_target_release "$__versions__is_same_target_release__candidate" "$2"
}

versions__format__load_formats "$SHELLOPS_DIR/lib"
