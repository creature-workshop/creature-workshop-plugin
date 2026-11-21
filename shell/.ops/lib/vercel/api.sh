#!/bin/sh
import \
  "$SHELLOPS_DIR/lib/env/api.sh" \
  "$SHELLOPS_DIR/lib/fingerprint/api.sh" \
  "$SHELLOPS_DIR/lib/node/api.sh" \
  "$SHELLOPS_DIR/lib/self/api.sh" \
  "$SHELLOPS_DIR/lib/self/assert.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
The Vercel library: what the deployment target vercel
(vercel.deployment.op.sh, beside this file) runs, and what the vercel tool
installs. Each deploy pulls the project's remote config, builds in the
pipeline, and uploads the prebuilt output, printing the deployment URL.
Auth is VERCEL_TOKEN (secret) plus VERCEL_ORG_ID/VERCEL_PROJECT_ID from
the environment; the CLI reads the pair itself and the token is passed
explicitly.
MODULE

fingerprint__secret VERCEL_TOKEN
fingerprint__input VERCEL_ORG_ID
fingerprint__input VERCEL_PROJECT_ID

: <<'PUB_FUN'
Prints the tools this adaptor runs, as a struct array, for the deployment
facade to install from the repository's tools declaration: the Vercel CLI,
declared as vercel.

usage: vercel__needs
PUB_FUN
vercel__needs() {
  @arr __vercel__needs__out vercel
  println "$__vercel__needs__out"
}

: <<'PUB_FUN'
Installs the pinned CLI under the CLI home and shims `vercel` onto
PATH, persistently via lib/self. Node's bundled npm materializes the
CLI's dependency tree (the package declares dozens of unbundled runtime
deps, so a bare tarball cannot run), prefix-scoped under the CLI home —
nothing global, nothing on PATH beyond the shim. The ecosystem's own
resolver for the ecosystem's tree, the way cargo is for a crate.

usage: vercel__install_cli "59.10.0"
PUB_FUN
vercel__install_cli() {
  __vercel__install_cli__version="${1:?usage: vercel__install_cli <version>}"
  __vercel__install_cli__dir="$(__vercel__cli_home)/vercel-${__vercel__install_cli__version}"

  if [ -x "$__vercel__install_cli__dir/bin/vercel" ]; then
    log "vercel CLI $__vercel__install_cli__version already installed"
    __vercel__export_cli_env "$__vercel__install_cli__dir"
    return
  fi

  node__assert_npm || return 1
  log "installing vercel CLI ${__vercel__install_cli__version}"
  mkdir -p "$__vercel__install_cli__dir"
  npm install \
    --prefix "$__vercel__install_cli__dir" \
    --no-fund \
    --no-audit \
    "vercel@${__vercel__install_cli__version}"
  __vercel__write_shim "$__vercel__install_cli__dir"
  __vercel__export_cli_env "$__vercel__install_cli__dir"
  log "vercel CLI ready at $__vercel__install_cli__dir/bin/vercel"
}

: <<'PUB_FUN'
Removes the CLI home, taking every installed CLI version with it.

usage: vercel__uninstall_cli
PUB_FUN
vercel__uninstall_cli() {
  __vercel__uninstall_cli__home="$(__vercel__cli_home)"

  if [ -d "$__vercel__uninstall_cli__home" ]; then
    log "removing the vercel CLI"
    rm -rf "$__vercel__uninstall_cli__home"
  else
    log "vercel CLI not installed, nothing to remove"
  fi
}

__vercel__cli_home() {
  echo "${VERCEL_CLI_HOME:-$(self__tool_home .vercel-cli)}"
}

: <<'FUN'
Writes the `vercel` shim into the install dir's bin. The package's bin
entry is dist/vc.js; the shim execs it through whatever node is on
PATH, and only the shim's dir goes on PATH — not node_modules/.bin
with every dependency's binaries.
FUN
__vercel__write_shim() {
  node__write_shim "$1" vercel vercel/dist/vc.js
}

__vercel__export_cli_env() {
  export PATH="$1/bin:${PATH}"
  self__add_persistent_path "$1/bin"
}

: <<'PUB_FUN'
Asserts that the vercel CLI is available. Returns 1 with a hint pointing
at the ops.lock entry that provisions it if it is missing.

usage: vercel__assert_cli
PUB_FUN
vercel__assert_cli() {
  @obj __vercel__assert_cli__obj_1 '.version' '<version>'
  self__assert_tool vercel script "$__vercel__assert_cli__obj_1" \
    "" \
    "The CLI runs on Node; provision that with the node tool."
}

: <<'PUB_FUN'
Asserts the full Vercel deploy environment, naming every missing
variable before failing.

usage: vercel__require_env
PUB_FUN
vercel__require_env() {
  env__require VERCEL_TOKEN VERCEL_ORG_ID VERCEL_PROJECT_ID
}

: <<'PUB_FUN'
Deploys the project as a preview and prints the deployment URL.

usage: vercel__preview <project-dir>
PUB_FUN
vercel__preview() {
  __vercel__preview__project_dir="${1:?usage: vercel__preview <project-dir>}"

  vercel__assert_cli || return 1
  vercel__require_env || return 1
  (
    cd "$__vercel__preview__project_dir" || exit
    vercel pull --yes --environment=preview --token "$VERCEL_TOKEN"
    vercel build --token "$VERCEL_TOKEN"
    vercel deploy --prebuilt --token "$VERCEL_TOKEN"
  )
}

: <<'PUB_FUN'
Deploys the project to production and prints the deployment URL.

usage: vercel__production <project-dir>
PUB_FUN
vercel__production() {
  __vercel__production__project_dir="${1:?usage: vercel__production <project-dir>}"

  vercel__assert_cli || return 1
  vercel__require_env || return 1
  (
    cd "$__vercel__production__project_dir" || exit
    vercel pull --yes --environment=production --token "$VERCEL_TOKEN"
    vercel build --prod --token "$VERCEL_TOKEN"
    vercel deploy --prebuilt --prod --token "$VERCEL_TOKEN"
  )
}

: <<'PUB_FUN'
Prints the deployment URL out of a deploy's captured output: the last
https line, which is how the CLI reports the deployment it created.
Prints nothing when no such line exists.

usage: vercel__preview_url "$output"
PUB_FUN
vercel__preview_url() {
  println "$1" \
    | grep -E '^https://' \
    | tail -n 1 \
    || true
}
