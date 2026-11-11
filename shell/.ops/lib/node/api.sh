#!/bin/sh

import "$SHELLOPS_DIR/lib/http/api.sh"
import "$SHELLOPS_DIR/lib/self/api.sh"
import "$SHELLOPS_DIR/lib/self/assert.sh"
import "$SHELLOPS_DIR/lib/structs/api.sh"
import "$SHELLOPS_DIR/lib/xplat/api.sh"
import "$SHELLOPS_DIR/lib/node/packages.sh"

: <<'MODULE'
Node.js project automation API.

Provides Node toolchain installation plus the package-manager-aware
dependency install and package.json script runs used by CI jobs. The
package manager itself (pnpm/yarn) is provisioned through corepack, which
ships with Node and activates the exact version package.json pins.

The file is one unit rather than sections: toolchain provisioning,
package-manager activation, and project operations are the stages one CI
job runs in order, and each exists for the next. npm packages installed as
ops.lock tools are another concern and live in lib/node/packages.sh, loaded
here so one import brings the whole module.
MODULE

: <<'CONST'
The package manager a project's lockfile commits it to; node__package_manager
answers one and node__install_deps dispatches on it.
CONST
@enum __node__PACKAGE_MANAGER PNPM YARN NPM

NODE_FNM_BASE_URL="https://github.com/Schniz/fnm/releases/download"

: <<'PUB_FUN'
Downloads the fnm binary release for the host platform into the fnm home
and adds it to PATH, persistently via lib/self.

  node__install_fnm "1.39.0"
PUB_FUN
node__install_fnm() {
  __node__install_fnm__version="${1:?usage: node__install_fnm <version>}"

  if __node__fnm_already_installed; then
    log "fnm already installed"
    __node__export_fnm_env
    return
  fi

  __node__install_fnm__filename="$(__node__fnm_asset_name)"
  __node__install_fnm__url="${NODE_FNM_BASE_URL}/v${__node__install_fnm__version}/${__node__install_fnm__filename}"

  log "downloading fnm ${__node__install_fnm__version} from ${__node__install_fnm__url}"
  __node__download_and_unzip "$__node__install_fnm__url"
  __node__export_fnm_env
  log "fnm $(fnm --version) ready"
}

: <<'PUB_FUN'
Removes the fnm home, taking every fnm-managed Node version with it.

  node__uninstall_fnm
PUB_FUN
node__uninstall_fnm() {
  __node__uninstall_fnm__home="$(__node__fnm_home)"

  if [ -d "$__node__uninstall_fnm__home" ]; then
    log "removing fnm and its Node versions"
    rm -rf "$__node__uninstall_fnm__home"
  else
    log "fnm not installed, nothing to remove"
  fi
}

: <<'PUB_FUN'
Installs a Node version through fnm and makes it the default. The default
alias's bin dir goes onto PATH, persistently via lib/self, so later job
steps reach node without any fnm environment of their own. The alias is
relinked relative to the fnm home, so the home can move with a CI cache.

  node__install_node "24.20.0"
PUB_FUN
node__install_node() {
  __node__install_node__version="${1:?usage: node__install_node <version>}"

  node__assert_fnm || return 1
  FNM_DIR="$(__node__fnm_home)" fnm install "$__node__install_node__version"
  FNM_DIR="$(__node__fnm_home)" fnm default "$__node__install_node__version"
  __node__relink_default_alias

  __node__install_node__bin_dir="$(__node__fnm_home)/aliases/default/bin"
  export PATH="${__node__install_node__bin_dir}:${PATH}"
  self__add_persistent_path "$__node__install_node__bin_dir"
  log "node $(node --version) ready"
}

: <<'PUB_FUN'
Removes a Node version from fnm's store.

  node__uninstall_node "24.20.0"
PUB_FUN
node__uninstall_node() {
  __node__uninstall_node__version="${1:?usage: node__uninstall_node <version>}"

  node__assert_fnm || return 1
  FNM_DIR="$(__node__fnm_home)" fnm uninstall "$__node__uninstall_node__version"
}

__node__fnm_home() {
  echo "${NODE_FNM_HOME:-$(self__tool_home .fnm)}"
}

: <<'FUN'
Point aliases/default at its Node version by a path relative to the fnm home.
`fnm default` writes the link absolute, which pins the home to the directory
it was installed in; relative, a cache restored elsewhere still resolves. A
link that is missing or already points outside the home is left alone.
FUN
__node__relink_default_alias() {
  __node__relink_default_alias__home="$(__node__fnm_home)"
  __node__relink_default_alias__alias="$__node__relink_default_alias__home/aliases/default"
  __node__relink_default_alias__target="$(readlink "$__node__relink_default_alias__alias")" || return 0

  case "$__node__relink_default_alias__target" in
    "$__node__relink_default_alias__home"/*)
      rm -f "$__node__relink_default_alias__alias"
      ln -s \
        "..${__node__relink_default_alias__target#"$__node__relink_default_alias__home"}" \
        "$__node__relink_default_alias__alias"
      ;;
  esac
}

__node__fnm_already_installed() {
  [ -x "$(__node__fnm_home)/fnm" ]
}

: <<'FUN'
Returns the zip asset fnm publishes for the host platform.

  __node__fnm_asset_name  ->  fnm-linux.zip  (on an x86_64 Linux host)
FUN
__node__fnm_asset_name() {
  if [ "$(xplat__os)" = "darwin" ]; then
    echo "fnm-macos.zip"
    return
  fi

  @get __node__fnm_asset_name__out \
    '{"aarch64": "fnm-arm64.zip", "armv7l": "fnm-arm32.zip"}' \
    ".\"$(xplat__arch_uname)\"" \
    "fnm-linux.zip"
  println "$__node__fnm_asset_name__out"
}

__node__download_and_unzip() {
  __node__download_and_unzip__home="$(__node__fnm_home)"

  mkdir -p "$__node__download_and_unzip__home"
  __node__download_and_unzip__tmpfile="$(mktemp)"

  if ! http__download "$1" "$__node__download_and_unzip__tmpfile"; then
    return 1
  fi

  unzip -o -q "$__node__download_and_unzip__tmpfile" -d "$__node__download_and_unzip__home"
  rm -f "$__node__download_and_unzip__tmpfile"
  chmod +x "$__node__download_and_unzip__home/fnm"
}

__node__export_fnm_env() {
  __node__export_fnm_env__home="$(__node__fnm_home)"

  export PATH="${__node__export_fnm_env__home}:${PATH}"
  self__add_persistent_path "$__node__export_fnm_env__home"
}

: <<'PUB_FUN'
Asserts that the fnm binary is available. Returns 1 with a hint pointing
at the ops.lock entry that provisions it if it is missing.

  node__assert_fnm
PUB_FUN
node__assert_fnm() {
  self__assert_tool fnm "" "" \
    'The node entry already carries "needs": ["fnm"], so installing node pulls it in.'
}

: <<'PUB_FUN'
Asserts that the node binary is available. Returns 1 with a hint pointing
at the ops.lock entry that provisions it if it is missing.

  node__assert_node
PUB_FUN
node__assert_node() {
  @obj __node__assert_node__obj_1 '.version' '<version>'
  self__assert_tool node script "$__node__assert_node__obj_1"
}

: <<'PUB_FUN'
Asserts that the npm binary is available. Returns 1 with a hint: npm is
not a standalone tool, it ships with Node.

usage: node__assert_npm
PUB_FUN
node__assert_npm() {
  if command -v npm >/dev/null 2>&1; then
    return 0
  fi

  error "npm is not installed"
  hint "npm ships with Node; provision it with: shell/ops install node"
  return 1
}

: <<'PUB_FUN'
Prints the package manager the project's lockfile commits it to.

  node__package_manager path/to/project  ->  pnpm

Recognizes pnpm-lock.yaml (pnpm), yarn.lock (yarn), and package-lock.json
(npm). A project with no recognized lockfile fails: CI installs must be
reproducible, and only a lockfile makes them so.
PUB_FUN
node__package_manager() {
  __node__package_manager__project_dir="${1:?usage: node__package_manager <project-dir>}"

  if [ -f "$__node__package_manager__project_dir/pnpm-lock.yaml" ]; then
    println "$__node__PACKAGE_MANAGER_PNPM"
  elif [ -f "$__node__package_manager__project_dir/yarn.lock" ]; then
    println "$__node__PACKAGE_MANAGER_YARN"
  elif [ -f "$__node__package_manager__project_dir/package-lock.json" ]; then
    println "$__node__PACKAGE_MANAGER_NPM"
  else
    error "No lockfile found in $__node__package_manager__project_dir"
    hint "Commit a pnpm-lock.yaml, yarn.lock, or package-lock.json so installs are reproducible."
    return 1
  fi
}

: <<'PUB_FUN'
Activates the package manager version package.json pins via corepack.

Corepack ships with Node and reads the `packageManager` field; activating
through it is what makes the pnpm/yarn on PATH the pinned version rather
than whatever the image happens to carry. A project without a
`packageManager` field is left on the bundled npm, which needs no
activation.

  node__prepare_package_manager path/to/project
PUB_FUN
node__prepare_package_manager() {
  __node__prepare_package_manager__project_dir="${1:?usage: node__prepare_package_manager <project-dir>}"

  __node__prepare_package_manager__pin="$(__node__package_manager_pin "$__node__prepare_package_manager__project_dir")"
  if ! @defined "$__node__prepare_package_manager__pin"; then
    log "no packageManager pin in package.json, keeping the bundled npm"
    return 0
  fi

  export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
  corepack enable
  (
    cd "$__node__prepare_package_manager__project_dir" || exit
    corepack install
  )
}

: <<'FUN'
Prints the package.json packageManager pin, empty when the file or the
field is absent.

  __node__package_manager_pin path/to/project  ->  pnpm@10.33.3
FUN
__node__package_manager_pin() {
  [ -f "$1/package.json" ] || return 0
  @get __node__package_manager_pin__out "$(cat "$1/package.json")" '.packageManager' ''
  println "$__node__package_manager_pin__out"
}

: <<'PUB_FUN'
Installs the project's dependencies exactly as the lockfile records them.

Dispatches on node__package_manager; every branch refuses to update the
lockfile, so a drifted package.json fails the job instead of silently
rewriting the pin.

  node__install_deps path/to/project
PUB_FUN
node__install_deps() {
  __node__install_deps__project_dir="${1:?usage: node__install_deps <project-dir>}"

  __node__install_deps__pm="$(node__package_manager "$__node__install_deps__project_dir")" || return 1
  (
    cd "$__node__install_deps__project_dir" || exit
    case "$__node__install_deps__pm" in
      "$__node__PACKAGE_MANAGER_PNPM") __node__install_deps_pnpm ;;
      "$__node__PACKAGE_MANAGER_YARN") __node__install_deps_yarn ;;
      "$__node__PACKAGE_MANAGER_NPM") __node__install_deps_npm ;;
    esac
  )
}

__node__install_deps_pnpm() {
  pnpm install --frozen-lockfile
}

__node__install_deps_yarn() {
  yarn install --frozen-lockfile
}

__node__install_deps_npm() {
  npm ci
}

: <<'PUB_FUN'
Runs a package.json script through the project's own package manager.

  node__run_script path/to/project lint
PUB_FUN
node__run_script() {
  __node__run_script__project_dir="${1:?usage: node__run_script <project-dir> <script>}"
  __node__run_script__script="${2:?usage: node__run_script <project-dir> <script>}"

  __node__run_script__pm="$(node__package_manager "$__node__run_script__project_dir")" || return 1
  (
    cd "$__node__run_script__project_dir" || exit
    "$__node__run_script__pm" run "$__node__run_script__script"
  )
}

node__lint() {
  node__run_script "${1:?usage: node__lint <project-dir>}" lint
}

node__build() {
  node__run_script "${1:?usage: node__build <project-dir>}" build
}
