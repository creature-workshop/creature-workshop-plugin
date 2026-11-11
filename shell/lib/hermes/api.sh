#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/self/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh"

: <<'MODULE'
Hermes Agent, `hermes`, as a pinned tool, so that a job can run
`hermes plugins validate` on the tree the catalog pins.

The install clones the Hermes Agent repository and runs the vendor installer
from the pinned commit, which brings its own uv and Python, checks out that
commit and publishes `hermes`. It runs with HOME set to the version's
directory in the tools home, so the commands it publishes and the shell files
it edits stay inside that directory, and a workstation's own Hermes Agent is
left alone.

HERMES_REPO_URL names the repository to clone, and GitHub is the default. CI
sets it to the copy on the project's GitLab, ksoft/hermes/hermes-agent, which
shell/actions/hermes/sync-copy keeps in step with GitHub.

The tool plugin shell/tools/hermes.tool.op.sh hands over the version and the
commit that .ops/config/tools.yaml pins.
MODULE

# CONST: The Hermes Agent repository on GitHub, which the copy on GitLab follows.
__hermes__UPSTREAM="https://github.com/NousResearch/hermes-agent.git"

# CONST: The branch the vendor installer follows, and the one the clone starts on.
__hermes__BRANCH="main"

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
Prints the repository the install clones: HERMES_REPO_URL when set, otherwise
Hermes Agent on GitHub.
PUB_FUN
hermes__repository() {
  println "${HERMES_REPO_URL:-$__hermes__UPSTREAM}"
}

: <<'PUB_FUN'
Prints true when Hermes Agent version $1 is installed in the tools home, false
otherwise.
PUB_FUN
hermes__installed() {
  @succeeds __hermes__installed__answer [ -x "$(hermes__bin_dir "$1")/hermes" ]
  println "$__hermes__installed__answer"
}

: <<'PUB_FUN'
Installs Hermes Agent version $1, which is commit $2 of the Hermes repository, into
the tools home and puts `hermes` on PATH. Both values come from the tools
declaration through the tool plugin; an empty one fails. A version that is
already installed is only put on PATH.

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

  __hermes__run_installer "$1" "$2" || return 1
  __hermes__export_env "$1"
  log "hermes $1 ready"
}

: <<'PUB_FUN'
Removes Hermes Agent version $1 from the tools home.
PUB_FUN
hermes__uninstall() {
  rm -rf "$(hermes__install_dir "$1")"
}

: <<'FUN'
Clones the repository at commit $2, then runs the installer from that commit
for version $1, with HOME and the Hermes home inside the version's directory.
A checkout left by an install that did not finish is replaced.
The installer finds the clone, updates its branch, and checks out the pinned
commit; --force-commit makes it do that when the branch is already past the
commit. The browser and the computer-use driver are skipped, because
validating a plugin needs neither.
FUN
__hermes__run_installer() {
  __hermes__run_installer__dir="$(hermes__install_dir "$1")"
  __hermes__run_installer__checkout="$__hermes__run_installer__dir/hermes-agent"
  __hermes__run_installer__script="$__hermes__run_installer__dir/install.sh"

  mkdir -p "$__hermes__run_installer__dir"
  log "installing hermes $1 at $2"
  rm -rf "$__hermes__run_installer__checkout"
  __hermes__clone "$2" "$__hermes__run_installer__checkout" || return 1
  __hermes__in_clone "$__hermes__run_installer__checkout" git__file_at "$2" scripts/install.sh \
    > "$__hermes__run_installer__script" \
    || return 1
  HOME="$__hermes__run_installer__dir" bash "$__hermes__run_installer__script" \
    --commit "$2" \
    --force-commit \
    --dir "$__hermes__run_installer__checkout" \
    --hermes-home "$__hermes__run_installer__dir/home" \
    --non-interactive \
    --skip-browser \
    --skip-computer-use
}

: <<'FUN'
Clones the repository that hermes__repository names into the directory $2 and
makes sure the clone holds commit $1. When that repository does not hold the
commit, as when the copy on GitLab has not yet caught up with a new pin, the
commit comes from GitHub instead. The clone leaves file contents on the server
until a checkout needs them. shellops' git module has no helper for a clone
or for fetching one commit by its hash, so those two steps call git directly.

args:
  $1  The full commit hash to install
  $2  The directory to clone into
FUN
__hermes__clone() {
  log "cloning $(__hermes__repository_label)"
  git clone \
    --quiet \
    --filter=blob:none \
    --branch "$__hermes__BRANCH" \
    "$(hermes__repository)" \
    "$2" \
    || return 1

  if @is_true "$(__hermes__holds_commit "$2" "$1")"; then
    return 0
  fi

  warn "$(__hermes__repository_label) does not hold $1; fetching it from GitHub"
  git -C "$2" fetch --quiet "$__hermes__UPSTREAM" "$1"
}

: <<'FUN'
Prints the repository the install clones, without the credentials a CI job
puts in it, for log lines.

    __hermes__repository_label  ->  https://gitlab.example/ksoft/hermes/hermes-agent.git
FUN
__hermes__repository_label() {
  hermes__repository | sed 's#//[^/@]*@#//#'
}

: <<'FUN'
Prints true when the clone in the directory $1 holds commit $2, false
otherwise.
FUN
__hermes__holds_commit() {
  @succeeds __hermes__holds_commit__answer __hermes__in_clone "$1" git__ref_exists "$2"
  println "$__hermes__holds_commit__answer"
}

: <<'FUN'
Runs the shellops git helper $2, with the rest of the arguments, on the clone
in the directory $1, in a subshell so that the rest of the program keeps its
own repository.

    __hermes__in_clone /opt/hermes-agent/hermes-2026.9.24/hermes-agent git__ref_exists f97608f...

args:
  $1     The clone's directory
  $2...  The helper and its arguments
FUN
__hermes__in_clone() {
  (
    # shellcheck disable=SC2034  # the shellops git helpers read it
    GIT_REPO="$1"
    shift
    "$@"
  )
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
