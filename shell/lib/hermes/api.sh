#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/self/api.sh" \
  "$PROJ/shell/lib/hermes/mirror.sh"

: <<'MODULE'
Hermes Agent, `hermes`, as a pinned tool, so that a job can run
`hermes plugins validate` on the tree the catalog pins.

When HERMES_MIRROR_URL is set, as it is in CI, the version comes from the
copy in the GitLab generic package registry (mirror.sh beside this file).
Otherwise the vendor's installer, taken from the pinned commit, clones that
commit, brings its own uv and Python, and publishes `hermes`. It runs with
HOME set to the version's directory in the tools home, so the commands it
publishes and the shell files it edits stay inside that directory, and a
workstation's own Hermes Agent is left alone.

The tool plugin shell/tools/hermes.tool.op.sh hands over the version and the
commit that .ops/config/tools.yaml pins.
MODULE

: <<'PUB_FUN'
Prints the directory Hermes Agent versions install under: HERMES_TOOL_HOME when set,
otherwise the hermes-agent entry of the tools home.
PUB_FUN
hermes__home() {
  println "${HERMES_TOOL_HOME:-$(self__tool_home .hermes-agent)}"
}

: <<'PUB_FUN'
Prints the directory that holds everything Hermes Agent version $1 installs.

    hermes__install_dir 2026.9.24  ->  /home/me/.hermes-agent/hermes-2026.9.24
PUB_FUN
hermes__install_dir() {
  println "$(hermes__home)/hermes-$1"
}

: <<'PUB_FUN'
Prints the directory that holds the `hermes` command of version $1, the one
PATH gets. The installer publishes the command under HOME/.local/bin, and HOME
is the version's directory while it runs.
PUB_FUN
hermes__bin_dir() {
  println "$(hermes__install_dir "$1")/.local/bin"
}

: <<'PUB_FUN'
Prints true when Hermes Agent version $1 is installed in the tools home, false
otherwise.
PUB_FUN
hermes__installed() {
  @succeeds [ -x "$(hermes__bin_dir "$1")/hermes" ]
}

: <<'PUB_FUN'
Installs Hermes Agent version $1, which is commit $2 of the Hermes repository, into
the tools home and puts `hermes` on PATH. Both values come from the tools
declaration through the tool plugin; an empty one fails. A version that is
already installed is only put on PATH. The version comes from the mirror when
one is configured, and from the vendor installer otherwise.

args:
  $1  The version, for example 2026.9.24
  $2  The full commit hash of that version
PUB_FUN
hermes__install() {
  if ! @defined "${1:-}" || ! @defined "${2:-}"; then
    error "hermes__install: a version and a commit are required; .ops/config/tools.yaml pins them"
    return 1
  fi

  if @is_true "$(hermes__installed "$1")"; then
    log "hermes $1 already installed"
    __hermes__export_env "$1"
    return 0
  fi

  if @is_true "$(__hermes__from_mirror "$1")"; then
    hermes__mirror__fetch "$1" "$(hermes__home)" || return 1
  else
    __hermes__run_installer "$1" "$2" || return 1
  fi
  __hermes__export_env "$1"
  log "hermes $1 ready"
}

: <<'PUB_FUN'
Installs Hermes Agent version $1, commit $2, into the tools home with the vendor
installer, whether or not a mirror is configured. This is how a copy for the
mirror is made.

args:
  $1  The version, for example 2026.9.24
  $2  The full commit hash of that version
PUB_FUN
hermes__prepare() {
  __hermes__run_installer "$1" "$2"
}

: <<'PUB_FUN'
Removes Hermes Agent version $1 from the tools home.
PUB_FUN
hermes__uninstall() {
  rm -rf "$(hermes__install_dir "$1")"
}

: <<'FUN'
Prints true when Hermes Agent version $1 can come from the mirror: a mirror is
configured and holds a copy of it. Prints false otherwise, and says so when a
mirror is configured but has no copy, as when the registry refused the upload,
so the install falls back to the vendor installer.
FUN
__hermes__from_mirror() {
  if @is_false "$(hermes__mirror__configured)"; then
    println false
    return 0
  fi

  __hermes__from_mirror__held="$(hermes__mirror__has "$1")"
  if @is_false "$__hermes__from_mirror__held"; then
    warn "the mirror holds no copy of hermes $1; installing it with the vendor installer"
  fi

  println "$__hermes__from_mirror__held"
}

: <<'FUN'
Prints the address of the installer script at commit $1.
FUN
__hermes__installer_url() {
  println "https://raw.githubusercontent.com/NousResearch/hermes-agent/$1/scripts/install.sh"
}

: <<'FUN'
Downloads the installer at commit $2 and runs it for version $1, with HOME and
the Hermes home inside the version's directory. The browser and the
computer-use driver are skipped, because validating a plugin needs neither.
FUN
__hermes__run_installer() {
  __hermes__run_installer__dir="$(hermes__install_dir "$1")"
  __hermes__run_installer__script="$__hermes__run_installer__dir/install.sh"

  mkdir -p "$__hermes__run_installer__dir"
  log "installing hermes $1 at $2"
  curl -fsSL \
    -o "$__hermes__run_installer__script" \
    "$(__hermes__installer_url "$2")" \
    || return 1
  HOME="$__hermes__run_installer__dir" bash "$__hermes__run_installer__script" \
    --commit "$2" \
    --dir "$__hermes__run_installer__dir/hermes-agent" \
    --hermes-home "$__hermes__run_installer__dir/home" \
    --non-interactive \
    --skip-browser \
    --skip-computer-use
}

: <<'FUN'
Puts the bin directory of version $1 on PATH, for this shell and for every
later shell that sources .envrc.
FUN
__hermes__export_env() {
  __hermes__export_env__bin="$(hermes__bin_dir "$1")"
  export PATH="${__hermes__export_env__bin}:${PATH}"
  self__add_persistent_path "$__hermes__export_env__bin"
}
