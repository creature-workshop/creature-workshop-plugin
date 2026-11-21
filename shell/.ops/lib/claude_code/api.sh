#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/node/api.sh" \
  "$SHELLOPS_DIR/lib/self/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
The Claude Code CLI, `claude`, as a pinned tool.

Anthropic publishes the CLI as an npm package whose install step places the
native binary for the host platform inside it, and its own install script
fetches whichever version is current into the user's home. This library
installs the version ops.lock pins into the tools home instead, with Node's
bundled npm and prefix-scoped, so a job on a plain image provisions it like
any other tool, the tools cache carries it between jobs, and a bump is a
lock change. The binary is native, so the bin directory PATH carries links
straight to it and nothing runs through node.

The tool plugin beside this file, claude-code.tool.op.sh, hands the version
over. A lock entry naming this tool needs `node`, which is what brings npm.
MODULE

__claude_code__PACKAGE="@anthropic-ai/claude-code"

: <<'PUB_FUN'
Prints the directory Claude Code versions install under: CLAUDE_CODE_HOME
when set, otherwise the claude-code entry of the tools home.
PUB_FUN
claude_code__home() {
  println "${CLAUDE_CODE_HOME:-$(self__tool_home .claude-code)}"
}

: <<'PUB_FUN'
Prints the install directory for Claude Code version $1, the prefix npm
installs the package under.

    claude_code__install_dir 2.1.274  ->  /home/me/.claude-code/claude-code-2.1.274
PUB_FUN
claude_code__install_dir() {
  println "$(claude_code__home)/claude-code-$1"
}

: <<'PUB_FUN'
Prints the directory `claude` is linked in for version $1, the one PATH
gets. The package's own bin sits beside every dependency's, so PATH carries
this directory and not that one.
PUB_FUN
claude_code__bin_dir() {
  println "$(claude_code__install_dir "$1")/bin"
}

: <<'PUB_FUN'
Prints true when Claude Code version $1 is installed in the tools home,
false otherwise.
PUB_FUN
claude_code__installed() {
  @succeeds __claude_code__installed__out [ -x "$(claude_code__bin_dir "$1")/claude" ]
  println "$__claude_code__installed__out"
}

: <<'PUB_FUN'
Installs Claude Code version $1 into the tools home and puts `claude` on
PATH. The version comes from ops.lock through the tool plugin, the one place
it is written; an empty one fails. A version already installed is only put
on PATH.
PUB_FUN
claude_code__install() {
  if ! @defined "${1:-}"; then
    error "claude_code__install: a version is required; ops.lock pins it"
    return 1
  fi

  if @is_true "$(claude_code__installed "$1")"; then
    log "claude-code $1 already installed"
    __claude_code__export_env "$1"
    return 0
  fi

  __claude_code__npm_install "$1" || return 1
  __claude_code__link_claude "$1"
  __claude_code__export_env "$1"
  log "claude-code $1 ready"
}

: <<'PUB_FUN'
Removes Claude Code version $1 from the tools home.
PUB_FUN
claude_code__uninstall() {
  rm -rf "$(claude_code__install_dir "$1")"
}

: <<'FUN'
Installs the package at version $1 into that version's install directory
with Node's bundled npm, prefix-scoped: the package and the platform binary
its install step places land under that directory's node_modules and nothing
goes global.
FUN
__claude_code__npm_install() {
  __claude_code__npm_install__dir="$(claude_code__install_dir "$1")"

  node__assert_npm || return 1
  log "installing claude-code $1 from $__claude_code__PACKAGE"
  mkdir -p "$__claude_code__npm_install__dir"
  npm install \
    --prefix "$__claude_code__npm_install__dir" \
    --no-fund \
    --no-audit \
    "${__claude_code__PACKAGE}@$1"
}

: <<'FUN'
Links `claude` in the bin directory of version $1 to the native binary the
package's install step places. The link is relative, so an install directory
a CI cache restores under another path still resolves.
FUN
__claude_code__link_claude() {
  __claude_code__link_claude__bin="$(claude_code__bin_dir "$1")"

  mkdir -p "$__claude_code__link_claude__bin"
  ln -sf \
    "../node_modules/$__claude_code__PACKAGE/bin/claude.exe" \
    "$__claude_code__link_claude__bin/claude"
}

: <<'FUN'
Puts the bin directory of version $1 on PATH, for this shell and for every
later shell that sources .envrc.
FUN
__claude_code__export_env() {
  __claude_code__export_env__bin="$(claude_code__bin_dir "$1")"
  export PATH="${__claude_code__export_env__bin}:${PATH}"
  self__add_persistent_path "$__claude_code__export_env__bin"
}
