#!/bin/sh

: <<'FRAGMENT'
Runs one manager's own commands over one package: whether that manager carries
the package, whether it offers a given version, and the install itself. A
manager that cannot answer at all -- a wedged index, a lock it never got --
fails rather than answering "no such package" or "no such version", so an
infrastructure fault is never reported as something the repositories do not
carry, and the install stops instead of quietly taking the latest.

An install pins the version where the manager can pin one; where it cannot, or
where the pinned version is not on offer, it warns and takes the latest, so a
pin never costs the caller the install.

The package indexes are refreshed once per shell, ahead of the first install.
Anything that leaves them stale clears __system_packages__INDEXES_REFRESHED,
which puts the next install back in front of a refresh.
FRAGMENT

__system_packages__INDEXES_REFRESHED=false

__system_packages__refresh_indexes() {
  if [ "$__system_packages__INDEXES_REFRESHED" = true ]; then
    return 0
  fi

  for __system_packages__refresh_indexes__manager in $__system_packages__AVAILABLE; do
    __system_packages__refresh_indexes__update_cmd=$(__system_packages__cfg "$__system_packages__refresh_indexes__manager" "update")
    if @defined "$__system_packages__refresh_indexes__update_cmd"; then
      $__system_packages__refresh_indexes__update_cmd >/dev/null 2>&1 || true
    fi
  done

  __system_packages__INDEXES_REFRESHED=true
}

__system_packages__package_exists() {
  __system_packages__package_exists__cmd=$(__system_packages__cfg "$1" "exists")
  if ! @defined "$__system_packages__package_exists__cmd"; then
    error "Manager $1 does not support package existence checks"
    return 1
  fi

  __system_packages__package_exists__stderr="$($__system_packages__package_exists__cmd "$2" 2>&1 >/dev/null)"
  __system_packages__package_exists__status=$?

  if @is_zero "$__system_packages__package_exists__status"; then
    @true __system_packages__package_exists__out
    println "$__system_packages__package_exists__out"
    return 0
  fi

  if __system_packages__says_missing "$1" "$__system_packages__package_exists__status"; then
    @false __system_packages__package_exists__out
    println "$__system_packages__package_exists__out"
    return 0
  fi

  error "$1 could not answer whether $2 exists (status $__system_packages__package_exists__status): $__system_packages__package_exists__stderr"
  return 1
}

: <<'FUN'
Succeeds when the status is the one this manager exits with to say it carries
no such package, printing nothing either way.

A manager that declares no missing_status has no way to tell a clean negative
from a failure, so every non-zero status reads as "no such package" -- the
behaviour every manager had before apt declared one.

  __system_packages__says_missing apt 100  ->  succeeds
FUN
__system_packages__says_missing() {
  __system_packages__says_missing__declared=$(__system_packages__cfg "$1" "missing_status")

  if ! @defined "$__system_packages__says_missing__declared"; then
    return 0
  fi

  [ "$2" = "$__system_packages__says_missing__declared" ]
}

__system_packages__run_install() {
  __system_packages__run_install__manager="$1"
  __system_packages__run_install__package="$2"
  __system_packages__run_install__version="${3:-}"

  __system_packages__run_install__install_cmd=$(__system_packages__cfg "$__system_packages__run_install__manager" "install")
  __system_packages__run_install__version_fmt=$(__system_packages__cfg "$__system_packages__run_install__manager" "version_format")

  if [ -n "$__system_packages__run_install__version" ] && ! @defined "$__system_packages__run_install__version_fmt"; then
    warn "$__system_packages__run_install__manager does not support version pinning; installing latest $__system_packages__run_install__package"
    $__system_packages__run_install__install_cmd "$__system_packages__run_install__package"
    return
  fi

  if [ -z "$__system_packages__run_install__version" ] || ! @defined "$__system_packages__run_install__version_fmt"; then
    $__system_packages__run_install__install_cmd "$__system_packages__run_install__package"
    return
  fi

  __system_packages__run_install__offered="$(__system_packages__version_available \
    "$__system_packages__run_install__manager" \
    "$__system_packages__run_install__package" \
    "$__system_packages__run_install__version"
  )" || return 1

  if ! @is_true "$__system_packages__run_install__offered"; then
    warn "version $__system_packages__run_install__version not available for $__system_packages__run_install__package via $__system_packages__run_install__manager; installing latest"
    $__system_packages__run_install__install_cmd "$__system_packages__run_install__package"
    return
  fi

  __system_packages__run_install__spec="$(string__replace "$__system_packages__run_install__version_fmt" "{package}" "$__system_packages__run_install__package")"
  __system_packages__run_install__spec="$(string__replace "$__system_packages__run_install__spec" "{version}" "$__system_packages__run_install__version")"
  $__system_packages__run_install__install_cmd "$__system_packages__run_install__spec"
}

: <<'FUN'
Prints true when the manager offers the given version of the package, false
when it does not, and fails when the manager could not answer -- surfacing the
manager's own stderr, so the caller stops rather than reading a fault as a
version the repositories do not carry.

A manager that exits with its declared missing_status is a clean negative, and
so is a manager that exits zero over a listing the version is absent from. A
manager offering no version check answers false as well: it cannot confirm the
pin, and the install falls back to the latest rather than failing.

args:
  $1  The manager (apt, dnf, ...)
  $2  The package
  $3  The version to look for

  __system_packages__version_available apt jq 1.7.1  ->  true
FUN
__system_packages__version_available() {
  __system_packages__version_available__check_cmd=$(__system_packages__cfg "$1" "version_check")

  if ! @defined "$__system_packages__version_available__check_cmd"; then
    @false __system_packages__version_available__out
    println "$__system_packages__version_available__out"
    return 0
  fi

  __system_packages__version_available__stderr_file="$(mktemp)"
  __system_packages__version_available__listing="$($__system_packages__version_available__check_cmd \
    "$2" \
    2>"$__system_packages__version_available__stderr_file"
  )"
  __system_packages__version_available__status=$?
  __system_packages__version_available__stderr="$(cat "$__system_packages__version_available__stderr_file")"
  rm -f "$__system_packages__version_available__stderr_file"

  if @equals __system_packages__version_available__equals_1 "$__system_packages__version_available__status" 0; @is_true "$__system_packages__version_available__equals_1"; then
    __system_packages__listing_offers "$__system_packages__version_available__listing" "$3"
    return 0
  fi

  if __system_packages__says_missing "$1" "$__system_packages__version_available__status"; then
    @false __system_packages__version_available__out
    println "$__system_packages__version_available__out"
    return 0
  fi

  error "$1 could not answer whether $2 offers version $3 (status $__system_packages__version_available__status): $__system_packages__version_available__stderr"
  return 1
}

: <<'FUN'
Prints true when a manager's version listing carries the version, false when it
does not. The version is matched as literal text, so a version whose punctuation
would otherwise read as a regular expression still matches only itself.

args:
  $1  The listing the manager printed
  $2  The version to look for

  __system_packages__listing_offers "jq | 1.7.1-3 | jammy" 1.7.1  ->  true
FUN
__system_packages__listing_offers() {
  println "$1" | { @succeeds __system_packages__listing_offers__out grep -qF -- "$2"; println "$__system_packages__listing_offers__out"; }
}
