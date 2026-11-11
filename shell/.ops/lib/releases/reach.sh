#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/manifest/api.sh" \
  "$SHELLOPS_DIR/lib/promotion/api.sh" \
  "$SHELLOPS_DIR/lib/releases/files.sh" \
  "$SHELLOPS_DIR/lib/sites/api.sh" \
  "$SHELLOPS_DIR/lib/versions/api.sh"

: <<'MODULE'
On release, a version is put at the sites its rung names. Given a site and
a version, this finds the tag that records the version and asks the
promotion ladder whether a tag at that rung is put at the site; then the
version, the tag and its commit, is put there the way the site's kind says
(lib/sites/api.sh). A site that names no kind takes nothing. A promotion
puts the version at every site the rung names, in the ladder's order. So
the tag, and the branches that follow it, land wherever the rung is put and
nowhere else (ADRs 000020, 000026, 000027, 000051 and 000055). A project
that declares no ladder puts nothing anywhere.
MODULE

: <<'PUB_FUN'
Puts <version> at every site a tag at its rung is put at, in the ladder's
order. A refused site stops the ones after it. A project that declares no
ladder puts it nowhere, and says so. Non-zero when the ladder does not
climb the rung, or a site is refused (releases__release_reach says how).

Fails before any site is reached when the release files cannot be named
(__releases__reach__require_release_files says why).

Usage: releases__release_promote <version>
PUB_FUN
releases__release_promote() {
  __releases__release_promote__ladder="$(promotion__declared)" || return 1
  if ! @defined "$__releases__release_promote__ladder"; then
    log "No ladder is declared, so a ${1} tag is put nowhere."
    return 0
  fi

  __releases__release_promote__rung="$(promotion__rung_of_version "$1")" || return 1
  __releases__release_promote__sites="$(promotion__targets "$__releases__release_promote__ladder" "$__releases__release_promote__rung")" || return 1

  if @empty "$__releases__release_promote__sites"; then
    log "A ${__releases__release_promote__rung} tag reaches no site."
    return 0
  fi

  __releases__reach__require_release_files || return 1
  @join __releases__release_promote__join_1 "$__releases__release_promote__sites" ", "
  log "A ${__releases__release_promote__rung} tag reaches $__releases__release_promote__join_1."
  @any __releases__release_promote__refused __releases__reach__site_refused "$__releases__release_promote__sites" "$1"

  @is_false "$__releases__release_promote__refused"
}

: <<'FUN'
Fails when the release files cannot be named, before a promotion pushes
anything. Moving a branch masks those files in the provenance check, and
naming them needs the tools the declared ecosystems read their manifests
with, cargo for a workspace among them. A job missing one finds out here,
with the tag still unpushed, not at the first branch after the tag went up.
FUN
__releases__reach__require_release_files() {
  releases__release_files >/dev/null
}

: <<'FUN'
True when putting <version> at the wrapped <site> was refused, false when
it went through: releases__release_reach the other way up, so a walk over
the sites stops at the first refusal.

  $1 site   $2 version
FUN
__releases__reach__site_refused() {
  @unwrap __releases__reach__site_refused__unwrap_2 "$1"
  ! releases__release_reach "$__releases__reach__site_refused__unwrap_2" "$2"
}

: <<'PUB_FUN'
Puts <version> at the site <site>: the tag that records the version, and
its commit, put there the way the site's kind says, when a tag at the
version's rung is put at that site at all. A site the rung does not name
takes nothing, and so does one that names no kind; a project that declares
no ladder puts nothing anywhere. Non-zero when no tag records the version,
the ladder does not climb its rung or does not declare the site, or the
site refuses the version.

Usage: releases__release_reach <site> <version>
PUB_FUN
releases__release_reach() {
  __releases__release_reach__site="$1"

  __releases__release_reach__tag="$(versions__tag_for_version "$2")"
  if ! @defined "$__releases__release_reach__tag"; then
    error "release: no tag records ${2}."
    return 1
  fi
  __releases__release_reach__commit="$(git rev-parse --verify --quiet "${__releases__release_reach__tag}^{commit}")" || return 1

  __releases__release_reach__ladder="$(promotion__declared)" || return 1
  if ! @defined "$__releases__release_reach__ladder"; then
    log "No ladder is declared, so nothing is put at ${1}."
    return 0
  fi

  __releases__release_reach__rung="$(promotion__rung_of_version "$2")" || return 1
  __releases__release_reach__sites="$(promotion__targets "$__releases__release_reach__ladder" "$__releases__release_reach__rung")" || return 1

  if ! @println "$__releases__release_reach__sites" | grep -qFx -- "$__releases__release_reach__site"; then
    log "A ${__releases__release_reach__rung} tag reaches nothing at ${__releases__release_reach__site}."
    return 0
  fi

  __releases__release_reach__value="$(promotion__site "$__releases__release_reach__ladder" "$__releases__release_reach__site")" || return 1
  if @null __releases__release_reach__null_3; [ "$__releases__release_reach__value" = "$__releases__release_reach__null_3" ]; then
    error "release: the ${__releases__release_reach__ladder} ladder puts a ${__releases__release_reach__rung} tag at ${__releases__release_reach__site}, which it declares no site for."
    return 1
  fi
  if @is_false "$(sites__is_kinded "$__releases__release_reach__value")"; then
    log "${__releases__release_reach__site} names no kind; nothing is put there."
    return 0
  fi

  log "A ${__releases__release_reach__rung} tag reaches ${__releases__release_reach__site} with ${__releases__release_reach__commit}."
  @obj __releases__release_reach__version '.tag' "$__releases__release_reach__tag" '.commit' "$__releases__release_reach__commit"
  sites__put "$__releases__release_reach__site" "$__releases__release_reach__value" "$__releases__release_reach__version"
}
