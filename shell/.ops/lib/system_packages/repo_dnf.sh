#!/bin/sh

: <<'FRAGMENT'
Sets up a third-party dnf repository, two ways. A config naming a .repo file
hands that file to dnf as the vendor published it; a config carrying a base URL
and a signing key instead has the repository written out from them and the key
imported. A repository already set up is left as it is.
FRAGMENT

__system_packages__add_repo_dnf() {
  @get __system_packages__add_repo_dnf__repo_file "$2" '.repo_file' ''
  if @defined "$__system_packages__add_repo_dnf__repo_file"; then
    __system_packages__add_repo_dnf_from_file "$1" "$__system_packages__add_repo_dnf__repo_file"
    return
  fi

  __system_packages__add_repo_dnf_manual "$1" "$2"
}

__system_packages__add_repo_dnf_from_file() {
  __system_packages__add_repo_dnf_from_file__dest="/etc/yum.repos.d/${1}.repo"

  [ -f "$__system_packages__add_repo_dnf_from_file__dest" ] && return 0

  __system_packages__add_repo_dnf_from_file__repo_file=$(__system_packages__expand_placeholders "$2")
  sudo dnf config-manager addrepo --from-repofile="$__system_packages__add_repo_dnf_from_file__repo_file" 2>/dev/null \
    || sudo dnf config-manager --add-repo "$__system_packages__add_repo_dnf_from_file__repo_file"
}

__system_packages__add_repo_dnf_manual() {
  __system_packages__add_repo_dnf_manual__dest="/etc/yum.repos.d/${1}.repo"

  [ -f "$__system_packages__add_repo_dnf_manual__dest" ] && return 0

  @let "$2" __system_packages__add_repo_dnf_manual__ url gpg name
  @defined "$__system_packages__add_repo_dnf_manual__name" || __system_packages__add_repo_dnf_manual__name="$1"
  __system_packages__add_repo_dnf_manual__url=$(__system_packages__expand_placeholders "$__system_packages__add_repo_dnf_manual__url")
  __system_packages__add_repo_dnf_manual__gpg=$(__system_packages__expand_placeholders "$__system_packages__add_repo_dnf_manual__gpg")

  sudo tee "$__system_packages__add_repo_dnf_manual__dest" > /dev/null <<EOF
[$1]
name=$__system_packages__add_repo_dnf_manual__name
baseurl=$__system_packages__add_repo_dnf_manual__url
gpgcheck=1
gpgkey=$__system_packages__add_repo_dnf_manual__gpg
enabled=1
EOF

  sudo rpm --import "$__system_packages__add_repo_dnf_manual__gpg"
  __system_packages__add_repo_dnf_manual__status=$?
  @unlet __system_packages__add_repo_dnf_manual__ url gpg name
  return "$__system_packages__add_repo_dnf_manual__status"
}
