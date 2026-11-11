#!/bin/sh

: <<'FRAGMENT'
What the installer knows about each package manager and each distro: for apt,
brew, dnf and pacman, the command that finds the manager on the machine and the
commands it queries, installs, removes, updates and adds a repo with; for each
supported distro, the managers to try in order, its own first and brew last.

A caller reads one command out of the table with __system_packages__cfg:

  __system_packages__cfg dnf install  ->  "sudo dnf install -y"

Supporting a new manager takes a command object here, a word in
__system_packages__MANAGERS, and a place in the rows of the distros it serves.
FRAGMENT

: <<'FUN'
True (0) when this shell is root on a machine without sudo -- a fresh
container, before anything is installed.
FUN
__system_packages__root_without_sudo() {
  [ "$(id -u)" -eq 0 ] && ! command -v sudo >/dev/null 2>&1
}

# Every privileged command in the config below is spelled through sudo. Root
# without sudo installed runs them directly: this stand-in strips itself, and
# installing the sudo package later shadows it back out of use.
if __system_packages__root_without_sudo; then
  sudo() {  # public-name-check: allow -- a stand-in shadowing the sudo command
    "$@"
  }
fi

__system_packages__MANAGERS="apt brew dnf pacman"

# CONST: Each manager's command set is its own nested @obj, composed into the
# top-level config under the manager's key — @obj within @obj, so a
# manager's keys/values live in one self-contained object rather than as
# flat dotted paths on the parent.
#
# apt's install line is written for a machine with nobody watching it.
# --no-install-recommends holds the install down to what the requested
# tools actually need; a recommended package a tool merely suggests is
# one nothing here calls. DEBIAN_FRONTEND travels through env because
# sudo clears the environment it inherits, and without it a package whose
# configure step asks a question waits for an answer that never comes.
@obj __at1 \
    '.detect'         "apt" \
    '.exists'         "apt-cache show" \
    '.missing_status' "100" \
    '.installed'      "dpkg -s" \
    '.install'        "sudo env DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends" \
    '.remove'         "sudo apt remove -y" \
    '.update'         "sudo apt update" \
    '.version_check'  "apt-cache madison" \
    '.version_format' "{package}={version}*" \
    '.add_repo'       "__system_packages__add_repo_apt"
@obj __at2 \
    '.detect'         "brew" \
    '.exists'         "brew info" \
    '.installed'      "brew list --versions" \
    '.install'        "brew install" \
    '.remove'         "brew uninstall" \
    '.update'         "brew update" \
    '.add_repo'       "__system_packages__add_repo_brew"
@obj __at3 \
    '.detect'         "dnf" \
    '.exists'         "dnf info" \
    '.installed'      "rpm -q" \
    '.install'        "sudo dnf install -y" \
    '.remove'         "sudo dnf remove -y" \
    '.update'         "sudo dnf check-update || true" \
    '.version_check'  "dnf list available" \
    '.version_format' "{package}-{version}*" \
    '.add_repo'       "__system_packages__add_repo_dnf"
@obj __at4 \
    '.detect'         "pacman" \
    '.exists'         "pacman -Si" \
    '.installed'      "pacman -Q" \
    '.install'        "sudo pacman -S --noconfirm" \
    '.remove'         "sudo pacman -R --noconfirm" \
    '.update'         "sudo pacman -Sy" \
    '.add_repo'       "__system_packages__add_repo_pacman"
@obj __system_packages__CONFIG \
  '.apt' "$__at1" \
  '.brew' "$__at2" \
  '.dnf' "$__at3" \
  '.pacman' "$__at4"

# CONST: Each distro's row is a space-separated list: POSIX sh has no arrays.
@obj __system_packages__DISTROS \
  '.ubuntu'    "apt brew" \
  '.debian'    "apt brew" \
  '.linuxmint' "apt brew" \
  '.pop'       "apt brew" \
  '.fedora'    "dnf brew" \
  '.rhel'      "dnf brew" \
  '.centos'    "dnf brew" \
  '.arch'      "pacman brew" \
  '.manjaro'   "pacman brew" \
  '.macos'     "brew"

__system_packages__cfg() {
  @get __system_packages__cfg__out "$__system_packages__CONFIG" ".\"$1\".\"$2\"" ''
  println "$__system_packages__cfg__out"
}
