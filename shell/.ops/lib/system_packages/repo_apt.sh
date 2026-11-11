#!/bin/sh

: <<'FRAGMENT'
Sets up a third-party apt repository. It installs the repository's signing key
into a keyring of its own, then writes an apt source that trusts only that key
and asks only for this machine's architecture. A repository already set up is
left as it is; a new one leaves the package indexes due for a refresh.
FRAGMENT

__system_packages__add_repo_apt() {
  __system_packages__add_repo_apt__name="$1"
  __system_packages__add_repo_apt__config="$2"
  __system_packages__add_repo_apt__keyring="/etc/apt/keyrings/${__system_packages__add_repo_apt__name}.gpg"
  __system_packages__add_repo_apt__sources="/etc/apt/sources.list.d/${__system_packages__add_repo_apt__name}.list"

  [ -f "$__system_packages__add_repo_apt__sources" ] && return 0

  @let "$__system_packages__add_repo_apt__config" __system_packages__add_repo_apt__ url gpg component codename
  __system_packages__add_repo_apt__url=$(__system_packages__expand_placeholders "$__system_packages__add_repo_apt__url")
  __system_packages__add_repo_apt__gpg=$(__system_packages__expand_placeholders "$__system_packages__add_repo_apt__gpg")

  if ! @defined "$__system_packages__add_repo_apt__codename"; then
    __system_packages__add_repo_apt__codename="$__system_packages__OS_CODENAME"
  fi

  __system_packages__add_repo_apt__arch="$(xplat__arch)"

  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL "$__system_packages__add_repo_apt__gpg" | sudo gpg --dearmor -o "$__system_packages__add_repo_apt__keyring"

  echo "deb [arch=$__system_packages__add_repo_apt__arch signed-by=$__system_packages__add_repo_apt__keyring] $__system_packages__add_repo_apt__url $__system_packages__add_repo_apt__codename $__system_packages__add_repo_apt__component" \
    | sudo tee "$__system_packages__add_repo_apt__sources" > /dev/null

  __system_packages__INDEXES_REFRESHED=false
  @unlet __system_packages__add_repo_apt__ url gpg component codename
}
