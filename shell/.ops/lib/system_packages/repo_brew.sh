#!/bin/sh

: <<'FRAGMENT'
Sets up a third-party brew repository by tapping it. A repo config that names
no tap gives brew nothing to add, so it asks for nothing.
FRAGMENT

__system_packages__add_repo_brew() {
  @get __system_packages__add_repo_brew__tap "$2" '.tap'
  @defined "$__system_packages__add_repo_brew__tap" || return 0

  brew tap "$__system_packages__add_repo_brew__tap" 2>/dev/null || true
}
