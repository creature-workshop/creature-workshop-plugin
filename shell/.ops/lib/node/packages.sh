#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/self/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'FRAGMENT'
npm packages as ops.lock tools, for the npm channel.

Each tool is installed into a home of its own with Node's bundled npm,
prefix-scoped: the package and its dependency tree land under that home's
node_modules and nothing goes global. A CLI package names the script its
executable runs and gets a shim of the tool's name onto PATH; a library
package gets no shim, and the lib that drives it asks node__package_modules
where to resolve it. Installed means the pinned version sits under the home,
which is how a library with nothing on PATH is a tool like any other.

The homes share one root -- NODE_PACKAGES_HOME when set, otherwise the
node-packages tool home lib/self derives -- so a CI job caches every npm tool
in one place. lib/node/api.sh loads this file and lends it node__assert_npm.
FRAGMENT

: <<'PUB_FUN'
Prints the home an npm-channel tool is installed under.

  node__package_home puppeteer-core                     ->  /home/me/.node-packages/puppeteer-core
  NODE_PACKAGES_HOME=/p/npm node__package_home vercel   ->  /p/npm/vercel

args:
  $1  The tool name, its ops.lock key
PUB_FUN
node__package_home() {
  __node__package_home__tool="${1:?usage: node__package_home <tool>}"

  printf '%s/%s\n' "$(__node__packages_root)" "$__node__package_home__tool"
}

__node__packages_root() {
  println "${NODE_PACKAGES_HOME:-$(self__tool_home .node-packages)}"
}

: <<'PUB_FUN'
Prints the node_modules directory a tool's package resolves from.

  node__package_modules puppeteer-core  ->  /home/me/.node-packages/puppeteer-core/node_modules
PUB_FUN
node__package_modules() {
  __node__package_modules__tool="${1:?usage: node__package_modules <tool>}"

  printf '%s/node_modules\n' "$(node__package_home "$__node__package_modules__tool")"
}

: <<'PUB_FUN'
Prints the version of the package installed under a tool's home, nothing when
there is none.

  node__package_version puppeteer-core puppeteer-core  ->  25.9.0

args:
  $1  The tool name
  $2  The npm package name
PUB_FUN
node__package_version() {
  __node__package_version__tool="${1:?usage: node__package_version <tool> <package>}"
  __node__package_version__package="${2:?usage: node__package_version <tool> <package>}"
  __node__package_version__manifest="$(node__package_modules "$__node__package_version__tool")/$__node__package_version__package/package.json"

  [ -f "$__node__package_version__manifest" ] || return 0
  @get __node__package_version__out "$(cat "$__node__package_version__manifest")" '.version' ''
  println "$__node__package_version__out"
}

: <<'PUB_FUN'
Prints true when the pinned version of the package is installed under the
tool's home, false for another version or none.

  node__package_installed puppeteer-core puppeteer-core 25.9.0  ->  true

args:
  $1  The tool name
  $2  The npm package name
  $3  The pinned version
PUB_FUN
node__package_installed() {
  __node__package_installed__tool="${1:?usage: node__package_installed <tool> <package> <version>}"
  __node__package_installed__package="${2:?usage: node__package_installed <tool> <package> <version>}"
  __node__package_installed__version="${3:?usage: node__package_installed <tool> <package> <version>}"

  @succeeds __node__package_installed__out [ "$(node__package_version "$__node__package_installed__tool" "$__node__package_installed__package")" = "$__node__package_installed__version" ]
  println "$__node__package_installed__out"
}

: <<'PUB_FUN'
Installs the pinned version of a package under the tool's home. A home
already holding that version is left alone; any other version is replaced in
place, so a home holds one version and nothing downstream has to choose.

  node__package_install puppeteer-core puppeteer-core 25.9.0

args:
  $1  The tool name
  $2  The npm package name
  $3  The version to install
PUB_FUN
node__package_install() {
  __node__package_install__tool="${1:?usage: node__package_install <tool> <package> <version>}"
  __node__package_install__package="${2:?usage: node__package_install <tool> <package> <version>}"
  __node__package_install__version="${3:?usage: node__package_install <tool> <package> <version>}"
  __node__package_install__home="$(node__package_home "$__node__package_install__tool")"

  if @is_true "$(node__package_installed "$__node__package_install__tool" "$__node__package_install__package" "$__node__package_install__version")"; then
    log "$__node__package_install__package $__node__package_install__version already installed"
    return 0
  fi

  node__assert_npm || return 1
  log "installing $__node__package_install__package $__node__package_install__version"
  mkdir -p "$__node__package_install__home"
  npm install \
    --prefix "$__node__package_install__home" \
    --no-fund \
    --no-audit \
    "${__node__package_install__package}@${__node__package_install__version}"
  log "$__node__package_install__package ready under $(node__package_modules "$__node__package_install__tool")"
}

: <<'PUB_FUN'
Removes a tool's home and the package in it.

  node__package_uninstall puppeteer-core
PUB_FUN
node__package_uninstall() {
  __node__package_uninstall__tool="${1:?usage: node__package_uninstall <tool>}"
  __node__package_uninstall__home="$(node__package_home "$__node__package_uninstall__tool")"

  if [ -d "$__node__package_uninstall__home" ]; then
    log "removing $__node__package_uninstall__tool"
    rm -rf "$__node__package_uninstall__home"
  else
    log "$__node__package_uninstall__tool not installed, nothing to remove"
  fi
}

: <<'PUB_FUN'
Writes a shim of the tool's name that runs a script of the installed package
through whatever node is on PATH, and puts the shim's directory on PATH,
persistently via lib/self. Only that directory goes on PATH -- not
node_modules/.bin with every dependency's executables.

  node__package_shim vercel vercel dist/vc.js
  # /home/me/.node-packages/vercel/bin/vercel runs
  #   node_modules/vercel/dist/vc.js from beside itself

args:
  $1  The tool name, which names the shim
  $2  The npm package name
  $3  The script inside the package the executable runs
PUB_FUN
node__package_shim() {
  __node__package_shim__tool="${1:?usage: node__package_shim <tool> <package> <script>}"
  __node__package_shim__package="${2:?usage: node__package_shim <tool> <package> <script>}"
  __node__package_shim__script="${3:?usage: node__package_shim <tool> <package> <script>}"
  __node__package_shim__home="$(node__package_home "$__node__package_shim__tool")"

  node__write_shim \
    "$__node__package_shim__home" \
    "$__node__package_shim__tool" \
    "$__node__package_shim__package/$__node__package_shim__script"

  export PATH="$__node__package_shim__home/bin:$PATH"
  self__add_persistent_path "$__node__package_shim__home/bin"
}

: <<'PUB_FUN'
Writes a shim into a package home's bin that runs a script under that home's
node_modules through whatever node is on PATH. The shim locates the script
from its own path rather than an absolute one, so a home that moves -- a CI
cache restored under another checkout path -- still runs.

  node__write_shim /p/npm/vercel vercel vercel/dist/vc.js
  # /p/npm/vercel/bin/vercel

args:
  $1  The package home, holding node_modules
  $2  The shim's name
  $3  The script's path under node_modules
PUB_FUN
node__write_shim() {
  __node__write_shim__home="${1:?usage: node__write_shim <home> <name> <script>}"
  __node__write_shim__name="${2:?usage: node__write_shim <home> <name> <script>}"
  __node__write_shim__script="${3:?usage: node__write_shim <home> <name> <script>}"

  mkdir -p "$__node__write_shim__home/bin"
  __node__write_shim__marker='__PACKAGE_SCRIPT__'
  sed "s|$__node__write_shim__marker|$__node__write_shim__script|" \
    "$SHELLOPS_DIR/lib/node/package-shim.template.sh" \
    > "$__node__write_shim__home/bin/$__node__write_shim__name"
  chmod +x "$__node__write_shim__home/bin/$__node__write_shim__name"
}
