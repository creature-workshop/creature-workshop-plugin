#!/bin/sh
# private-file-check: allow -- the module's public surface, which only its channel plugin imports so far

import \
  "$SHELLOPS_DIR/lib/self/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Flathub applications as ops.lock tools, for the flatpak channel.

A tool of the channel is a Flatpak application, named by its application
id, installed from Flathub into the user's own installation, so nothing
needs root and nothing changes for other users of the host. Installed means
the application is present in the user installation at the pinned version.
Flathub serves one current build per branch, so a version is checked after
the install rather than requested from it; an entry that names a commit is
installed at that commit, which is the one way to hold an older build.

The exports directory of the user installation, where Flatpak writes a
launcher named after each application, goes on the recorded PATH, so an
installed application runs by its id like any other tool.
MODULE

# CONST: The remote every tool of the channel installs from.
__flatpak__REMOTE="flathub"

# CONST: Where the remote is added from when the user installation lacks it.
__flatpak__REMOTE_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

: <<'PUB_FUN'
Fails, saying what to declare, when the flatpak command is not on PATH. The
channel's dependency is the flatpak package of the system channel, so this
is reached only when a caller skips the channel.
PUB_FUN
flatpak__assert_cli() {
  if command -v flatpak >/dev/null 2>&1; then
    return 0
  fi
  error "flatpak is not installed; declare it under the system channel, which the flatpak channel depends on"
  return 1
}

: <<'PUB_FUN'
Prints the directory the user installation exports application launchers
into, which is where an installed application's command of its own id is.

  flatpak__exports_bin  ->  /home/me/.local/share/flatpak/exports/bin
PUB_FUN
flatpak__exports_bin() {
  println "${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/exports/bin"
}

: <<'PUB_FUN'
Adds the Flathub remote to the user installation when it is not there yet.
A remote already present is left as it is.
PUB_FUN
flatpak__ensure_remote() {
  flatpak remote-add --user --if-not-exists "$__flatpak__REMOTE" "$__flatpak__REMOTE_URL"
}

: <<'PUB_FUN'
Prints the version of an application installed in the user installation,
nothing when it is not installed.

  flatpak__installed_version no.mifi.losslesscut  ->  3.69.0

args:
  $1  The application id
PUB_FUN
flatpak__installed_version() {
  __flatpak__installed_version__app="${1:?usage: flatpak__installed_version <app>}"

  flatpak list --user --app --columns=application,version 2>/dev/null \
    | __flatpak__version_of "$__flatpak__installed_version__app"
}

: <<'FUN'
Reads lines of "<application id><tab><version>" on stdin and prints the
version of the application $1, nothing when no line names it.
FUN
__flatpak__version_of() {
  awk -F '\t' -v app="$1" '$1 == app { print $2; exit }'
}

: <<'PUB_FUN'
Prints true when the application is installed in the user installation at
the pinned version, false for another version or none.

  flatpak__installed no.mifi.losslesscut 3.69.0  ->  true

args:
  $1  The application id
  $2  The pinned version
PUB_FUN
flatpak__installed() {
  __flatpak__installed__app="${1:?usage: flatpak__installed <app> <version>}"
  __flatpak__installed__version="${2:?usage: flatpak__installed <app> <version>}"

  @succeeds __flatpak__installed__out [ "$(flatpak__installed_version "$__flatpak__installed__app")" = "$__flatpak__installed__version" ]
  println "$__flatpak__installed__out"
}

: <<'PUB_FUN'
Installs an application from Flathub into the user installation and puts
the exports directory on the recorded PATH. An application already there at
the pinned version is left alone. With a commit, that commit is installed;
without one, Flathub's current build is, and the install fails when its
version is not the pinned one, naming the version Flathub served, so the
lock stays true to what is on the host.

  flatpak__install no.mifi.losslesscut 3.69.0
  flatpak__install no.mifi.losslesscut 3.69.0 1a2b3c...

args:
  $1  The application id
  $2  The pinned version
  $3  The commit to install, optional
PUB_FUN
flatpak__install() {
  __flatpak__install__app="${1:?usage: flatpak__install <app> <version> [commit]}"
  __flatpak__install__version="${2:?usage: flatpak__install <app> <version> [commit]}"
  __flatpak__install__commit="${3:-}"

  if @is_true "$(flatpak__installed "$__flatpak__install__app" "$__flatpak__install__version")"; then
    log "$__flatpak__install__app $__flatpak__install__version already installed"
    __flatpak__export_path
    return 0
  fi

  flatpak__assert_cli || return 1
  flatpak__ensure_remote || return 1
  log "installing $__flatpak__install__app $__flatpak__install__version from $__flatpak__REMOTE"
  __flatpak__install_app "$__flatpak__install__app" "$__flatpak__install__commit" || return 1
  __flatpak__assert_version "$__flatpak__install__app" "$__flatpak__install__version" || return 1
  __flatpak__export_path
  log "$__flatpak__install__app ready as $(flatpak__exports_bin)/$__flatpak__install__app"
}

: <<'FUN'
Runs the install of the application $1, at the commit $2 when one is given.
FUN
__flatpak__install_app() {
  if @defined "$2"; then
    flatpak install --user --noninteractive --assumeyes --commit="$2" "$__flatpak__REMOTE" "$1"
  else
    flatpak install --user --noninteractive --assumeyes "$__flatpak__REMOTE" "$1"
  fi
}

: <<'FUN'
Fails when the application $1 is installed at a version other than $2,
saying which version Flathub served and how to pin it.
FUN
__flatpak__assert_version() {
  __flatpak__assert_version__found="$(flatpak__installed_version "$1")"
  if [ "$__flatpak__assert_version__found" = "$2" ]; then
    return 0
  fi
  error "$1: Flathub served version ${__flatpak__assert_version__found:-none}, and the declaration pins $2; move the pin to that version, or name the commit of $2 in the declaration"
  return 1
}

: <<'FUN'
Puts the exports directory on PATH now and on the recorded PATH, so an
installed application's launcher is found by its id.
FUN
__flatpak__export_path() {
  __flatpak__export_path__bin="$(flatpak__exports_bin)"
  export PATH="$__flatpak__export_path__bin:$PATH"
  self__add_persistent_path "$__flatpak__export_path__bin"
}

: <<'PUB_FUN'
Removes an application from the user installation. One that is not there is
left alone with a line saying so.

  flatpak__uninstall no.mifi.losslesscut

args:
  $1  The application id
PUB_FUN
flatpak__uninstall() {
  __flatpak__uninstall__app="${1:?usage: flatpak__uninstall <app>}"

  if ! @defined "$(flatpak__installed_version "$__flatpak__uninstall__app")"; then
    log "$__flatpak__uninstall__app not installed, nothing to remove"
    return 0
  fi
  log "removing $__flatpak__uninstall__app"
  flatpak uninstall --user --noninteractive --assumeyes "$__flatpak__uninstall__app"
}
