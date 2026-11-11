#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/xplat/api.sh" \
  "$SHELLOPS_DIR/lib/string/api.sh" \
  "$SHELLOPS_DIR/lib/system_packages/config.sh" \
  "$SHELLOPS_DIR/lib/system_packages/detect.sh" \
  "$SHELLOPS_DIR/lib/system_packages/operations.sh" \
  "$SHELLOPS_DIR/lib/system_packages/fallback.sh" \
  "$SHELLOPS_DIR/lib/system_packages/placeholders.sh" \
  "$SHELLOPS_DIR/lib/system_packages/repo_apt.sh" \
  "$SHELLOPS_DIR/lib/system_packages/repo_brew.sh" \
  "$SHELLOPS_DIR/lib/system_packages/repo_dnf.sh" \
  "$SHELLOPS_DIR/lib/system_packages/repo_pacman.sh"

: <<'MODULE'
Installs and removes system packages on whatever machine this runs on, across
apt, brew, dnf and pacman. system_packages__install, _remove, _update, _exists,
_installed, _add_repo and _distro are the whole surface a caller needs, and
they stay in this file because putting the parts beside it in the right order
is what this file is for: each one detects the machine before it acts, and an
install refreshes the package indexes before it asks for anything.

An install goes to the manager the distro prefers, and where that manager does
not carry the package, to the next one that does. A version is pinned where
the manager can pin one.

The parts live beside this file: config.sh holds the manager and distro tables,
detect.sh says what this machine is, operations.sh runs a manager's commands,
fallback.sh chooses between managers, and placeholders.sh with repo_apt.sh,
repo_brew.sh, repo_dnf.sh and repo_pacman.sh set up third-party repositories.
MODULE

: <<'FUN'
The package name a build toolchain is asked for by. Debian and its derivatives
carry the compilers as build-essential; everywhere else the name to ask for is
gcc. Any other package name is already the name to ask for.
FUN
__system_packages__normalize_build_tool() {
  __system_packages__normalize_build_tool__dist="$(__system_packages__read_distro_id)"
  if [ "$1" != "build-essential" ]; then
    echo "$1"
    return 0
  fi
  case "$__system_packages__normalize_build_tool__dist" in
    ubuntu|debian|linuxmint|pop) echo build-essential ;;
    *) echo gcc ;;
  esac
}

system_packages__exists() {
  if [ "$1" = "build-essential" ] && command -v cc >/dev/null 2>&1; then
    return 0
  fi

  __system_packages__detect_distro || return 1
  __system_packages__exists__normalized=$(__system_packages__normalize_build_tool "$1")

  for __system_packages__exists__manager in $__system_packages__AVAILABLE; do
    __system_packages__exists__carries="$(__system_packages__package_exists \
      "$__system_packages__exists__manager" \
      "$__system_packages__exists__normalized"
    )" || return 1

    if @is_true "$__system_packages__exists__carries"; then
      return 0
    fi
  done

  return 1
}

: <<'PUB_FUN'
Returns success when the package is actually installed on the system.

This differs from system_packages__exists, which only reports whether a
package is *available* in a configured repo (e.g. apt-cache show). Install
skip-logic must query the installed-package database (dpkg/rpm/pacman/brew),
otherwise every repo-known package looks "installed" and is never installed.

Usage: system_packages__installed git
PUB_FUN
system_packages__installed() {
  if [ "$1" = "build-essential" ] && command -v cc >/dev/null 2>&1; then
    return 0
  fi

  __system_packages__detect_distro || return 1
  __system_packages__installed__normalized=$(__system_packages__normalize_build_tool "$1")

  for __system_packages__installed__manager in $__system_packages__AVAILABLE; do
    __system_packages__installed__cmd=$(__system_packages__cfg "$__system_packages__installed__manager" "installed")
    ! @defined "$__system_packages__installed__cmd" && continue

    if $__system_packages__installed__cmd "$__system_packages__installed__normalized" >/dev/null 2>&1; then
      return 0
    fi
  done

  return 1
}

system_packages__install() {
  __system_packages__install__package="$1"
  __system_packages__install__version="${2:-}"

  # An explicit "latest" in the lockfile means "newest available", same
  # as leaving the version empty. Normalize it so we don't probe the host
  # manager for a literal version string of "latest".
  [ "$__system_packages__install__version" = "latest" ] && __system_packages__install__version=""

  if [ "$__system_packages__install__package" = "build-essential" ] && command -v cc >/dev/null 2>&1; then
    return 0
  fi

  __system_packages__detect_distro || return 1
  __system_packages__install__package=$(__system_packages__normalize_build_tool "$__system_packages__install__package")
  __system_packages__refresh_indexes

  __system_packages__install__manager=$(__system_packages__find_manager_for "$__system_packages__install__package") || return 1

  __system_packages__run_install "$__system_packages__install__manager" "$__system_packages__install__package" "$__system_packages__install__version"
}

system_packages__remove() {
  __system_packages__detect_distro || return 1

  __system_packages__remove__package=$(__system_packages__normalize_build_tool "$1")

  __system_packages__remove__remove_cmd=$(__system_packages__cfg "$(__system_packages__primary)" "remove")

  $__system_packages__remove__remove_cmd "$__system_packages__remove__package"
}

system_packages__update() {
  __system_packages__detect_distro || return 1

  __system_packages__update__update_cmd=$(__system_packages__cfg "$(__system_packages__primary)" "update")

  $__system_packages__update__update_cmd
}

: <<'PUB_FUN'
Configures a third-party package repository for the active manager.

The repo_json argument is a JSON object keyed by manager name (apt, dnf,
pacman). Only the entry matching the detected manager is used; others are
ignored. If the detected manager has no entry, this is a no-op.

Usage: system_packages__add_repo "$name" "$repo_json"
PUB_FUN
system_packages__add_repo() {
  __system_packages__detect_distro || return 1

  __system_packages__add_repo__manager="$(__system_packages__primary)"
  @get __system_packages__add_repo__config "$2" ".\"$__system_packages__add_repo__manager\""
  @defined "$__system_packages__add_repo__config" || return 0

  __system_packages__add_repo__handler=$(__system_packages__cfg "$__system_packages__add_repo__manager" "add_repo")
  @defined "$__system_packages__add_repo__handler" || return 0

  "$__system_packages__add_repo__handler" "$1" "$__system_packages__add_repo__config"
}

: <<'PUB_FUN'
Returns the detected distro ID (e.g. ubuntu, fedora, macos).

Usage: system_packages__distro
PUB_FUN
system_packages__distro() {
  __system_packages__detect_distro || return 1
  echo "$__system_packages__DISTRO"
}
