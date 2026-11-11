#!/bin/sh

: <<'FRAGMENT'
Which manager a package is installed from when the preferred one does not carry
it. system_packages__install calls __system_packages__find_manager_for, which
takes the first available manager carrying the package, in the priority order
detection settled on. Where that is not the preferred manager, it warns and
asks the person at the terminal to confirm the fallback; with nobody there to
answer it declines rather than install from somewhere unasked.

A manager that cannot answer whether it carries the package stops the search,
so a wedged index reads as the failure it is rather than sending the caller
away with "not found in any available package manager".
FRAGMENT

__system_packages__find_manager_for() {
  __system_packages__find_manager_for__package="$1"
  __system_packages__find_manager_for__primary="$(__system_packages__primary)"

  for __system_packages__find_manager_for__manager in $__system_packages__AVAILABLE; do
    __system_packages__find_manager_for__carries="$(__system_packages__package_exists \
      "$__system_packages__find_manager_for__manager" \
      "$__system_packages__find_manager_for__package"
    )" || return 1

    if ! @is_true "$__system_packages__find_manager_for__carries"; then
      continue
    fi

    if [ "$__system_packages__find_manager_for__manager" != "$__system_packages__find_manager_for__primary" ]; then
      warn "$__system_packages__find_manager_for__package not found in $__system_packages__find_manager_for__primary; found in $__system_packages__find_manager_for__manager"
      __system_packages__confirm_fallback "$__system_packages__find_manager_for__package" "$__system_packages__find_manager_for__manager" || return 1
    fi

    echo "$__system_packages__find_manager_for__manager"
    return 0
  done

  error "$__system_packages__find_manager_for__package not found in any available package manager (checked: $__system_packages__AVAILABLE)"
  return 1
}

__system_packages__confirm_fallback() {
  if [ ! -t 0 ]; then
    error "Non-interactive shell; cannot confirm fallback to $2 for $1"
    return 1
  fi

  printf 'Install %s via %s instead? [y/N] ' "$1" "$2"
  read -r __system_packages__confirm_fallback__reply
  case "$__system_packages__confirm_fallback__reply" in
    [Yy]) return 0 ;;
    *) return 1 ;;
  esac
}
