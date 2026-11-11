#!/bin/sh

: <<'FRAGMENT'
Which distro this shell runs on and which package managers it can reach.
__system_packages__detect_distro settles both on its first call and caches the
answer: it identifies the distro, then keeps the managers actually installed,
the ones that distro prefers first and any other supported manager after them.
It fails when the machine carries none of them.

Every other part of the installer reads the answer from here:
__system_packages__AVAILABLE lists the managers in priority order,
__system_packages__primary is the first of them, and __system_packages__DISTRO
with the OS version and codename describe the machine a repo is set up for.
FRAGMENT

# VAR: The managers found, in priority order, space-separated: POSIX sh has no arrays.
__system_packages__AVAILABLE=""

# VAR: The distribution id the machine reports, once detected.
__system_packages__DISTRO=""

# VAR: Whether detection has run, so it runs once per process.
__system_packages__DETECTED=false

# VAR: The OS version, once detected.
__system_packages__OS_VERSION=""

# VAR: The OS codename, once detected.
__system_packages__OS_CODENAME=""

__system_packages__primary() {
  echo "${__system_packages__AVAILABLE%% *}"
}

__system_packages__detect_distro() {
  if [ "$__system_packages__DETECTED" = true ]; then
    return 0
  fi

  __system_packages__DISTRO="$(__system_packages__read_distro_id)"
  __system_packages__read_os_release_fields

  @get __system_packages__detect_distro__priority "$__system_packages__DISTROS" ".\"$__system_packages__DISTRO\"" ''
  __system_packages__AVAILABLE=""

  if @defined "$__system_packages__detect_distro__priority"; then
    # shellcheck disable=SC2086
    __system_packages__collect_available $__system_packages__detect_distro__priority
  fi

  # shellcheck disable=SC2086
  __system_packages__collect_remaining $__system_packages__detect_distro__priority

  if [ -z "$__system_packages__AVAILABLE" ]; then
    error "No supported system package manager found"
    return 1
  fi

  __system_packages__DETECTED=true
}

__system_packages__read_distro_id() {
  if [ "$(uname -s)" = "Darwin" ]; then
    echo "macos"
    return
  fi

  if [ ! -f /etc/os-release ]; then
    error "No /etc/os-release defined"
    echo "unknown"
    return
  fi

  __system_packages__read_distro_id__id=$(. /etc/os-release && echo "${ID:-}")
  if ! @defined "$__system_packages__read_distro_id__id"; then
    error "No release ID defined in /etc/os-release"
    echo "unknown"
    return
  fi

  echo "$__system_packages__read_distro_id__id"
}

__system_packages__read_os_release_fields() {
  [ -f /etc/os-release ] || return 0

  __system_packages__OS_VERSION="$(. /etc/os-release && echo "${VERSION_ID:-}")"
  __system_packages__OS_CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
}

__system_packages__collect_available() {
  for __system_packages__collect_available__manager in "$@"; do
    __system_packages__collect_available__detect_cmd=$(__system_packages__cfg "$__system_packages__collect_available__manager" "detect")
    if @defined "$__system_packages__collect_available__detect_cmd" && command -v "$__system_packages__collect_available__detect_cmd" >/dev/null 2>&1; then
      __system_packages__AVAILABLE="${__system_packages__AVAILABLE:+$__system_packages__AVAILABLE }$__system_packages__collect_available__manager"
    fi
  done
}

__system_packages__collect_remaining() {
  __system_packages__collect_remaining__skip_list=" $* "

  for __system_packages__collect_remaining__manager in $__system_packages__MANAGERS; do
    case "$__system_packages__collect_remaining__skip_list" in
      *" $__system_packages__collect_remaining__manager "*) continue ;;
    esac

    __system_packages__collect_remaining__detect_cmd=$(__system_packages__cfg "$__system_packages__collect_remaining__manager" "detect")
    if @defined "$__system_packages__collect_remaining__detect_cmd" && command -v "$__system_packages__collect_remaining__detect_cmd" >/dev/null 2>&1; then
      __system_packages__AVAILABLE="${__system_packages__AVAILABLE:+$__system_packages__AVAILABLE }$__system_packages__collect_remaining__manager"
    fi
  done
}
