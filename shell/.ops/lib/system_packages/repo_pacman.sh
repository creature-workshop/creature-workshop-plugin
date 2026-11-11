#!/bin/sh

: <<'FRAGMENT'
Sets up a third-party pacman repository. It receives and locally signs the
repository's key when the config carries one, then appends the repository and
its signature level to pacman's configuration. A repository already there is
left as it is; a new one leaves the package indexes due for a refresh.
FRAGMENT

__system_packages__add_repo_pacman() {
  __system_packages__add_repo_pacman__name="$1"

  if grep -q "^\[$__system_packages__add_repo_pacman__name\]" /etc/pacman.conf 2>/dev/null; then
    return 0
  fi

  @let "$2" __system_packages__add_repo_pacman__ server siglevel key
  @defined "$__system_packages__add_repo_pacman__siglevel" || __system_packages__add_repo_pacman__siglevel='Optional TrustedOnly'
  __system_packages__add_repo_pacman__server=$(__system_packages__expand_placeholders "$__system_packages__add_repo_pacman__server")

  if @defined "$__system_packages__add_repo_pacman__key"; then
    sudo pacman-key --recv-keys "$__system_packages__add_repo_pacman__key"
    sudo pacman-key --lsign-key "$__system_packages__add_repo_pacman__key"
  fi

  sudo tee -a /etc/pacman.conf > /dev/null <<EOF

[$__system_packages__add_repo_pacman__name]
SigLevel = $__system_packages__add_repo_pacman__siglevel
Server = $__system_packages__add_repo_pacman__server
EOF

  __system_packages__INDEXES_REFRESHED=false
  @unlet __system_packages__add_repo_pacman__ server siglevel key
}
