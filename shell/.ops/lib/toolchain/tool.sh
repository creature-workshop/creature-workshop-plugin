#!/bin/sh

import "$SHELLOPS_DIR/lib/kinds/api.sh"

: <<'MODULE'
The tool kind: a tool ops install provisions through a plugin of its own,
where an installer script pair would otherwise stand.

A tool plugin is a plugin of kind tool (lib/kinds/api.sh says how a kind
loads), a file named <name>.tool.op.sh defining @tool.<name>() with these
roles, each handed the tool's ops.lock entry as a struct, the pinned
version under .version (ADR 000007):

  @summary                   What the tool is, in one line.
  @install <requirements>    Provisions the pinned version and puts it on
                             the recorded PATH. Non-zero fails the install.
  @uninstall <requirements>  Removes the pinned version.
  @installed <requirements>  Prints true when the pinned version is
                             installed, false otherwise. A plugin that
                             leaves it out is judged by its channel.

No role is required of every plugin. A plugin that answers @install
answers @uninstall too: it is an installer, and the script channel
(lib/toolchain/script.channel.op.sh) provisions its tool through it. A
plugin that answers neither is a project's own, carrying the roles the
project's kind adds, and its tool is provisioned by its channel or by the
installer script pair under plugins/tools and the project's scripts
directory.

A plugin of shellops' own sits beside the module that installs its tool,
lib/cursor_agent/cursor-agent.tool.op.sh for the Cursor CLI, and importing
this module loads every one under lib/. ops install loads a project's own
from its tools directory beside them.
MODULE

__toolchain__tool__ROLES="summary install uninstall installed"
__toolchain__tool__REQUIRED=""

: <<'PUB_FUN'
Loads and registers the tool plugin <name>, whose file has been imported,
and refuses one that answers @install without @uninstall or the reverse.
See kinds__load.
PUB_FUN
toolchain__tool__load() {
  kinds__load tool "$1" "$__toolchain__tool__ROLES" "$__toolchain__tool__REQUIRED" || return 1
  __toolchain__tool__assert_installer "$1"
}

: <<'PUB_FUN'
Finds and loads every tool plugin under <root>, refusing one that answers
@install without @uninstall or the reverse; a root that is not a directory
holds none. See kinds__scan.
PUB_FUN
toolchain__tool__load_all() {
  if [ ! -d "$1" ]; then
    return 0
  fi

  kinds__scan tool "$1" "$__toolchain__tool__ROLES" "$__toolchain__tool__REQUIRED" || return 1
  __toolchain__tool__assert_installers
}

: <<'PUB_FUN'
Prints the names of every tool plugin, as a struct array, in load order.
PUB_FUN
toolchain__tool__names() {
  kinds__names tool
}

: <<'PUB_FUN'
Prints the names of every tool plugin that answers @install, as a struct
array, in load order: the tools the script channel provisions through a
plugin rather than a script pair.

    toolchain__tool__installers  ->  ["cursor-agent","claude-code"]
PUB_FUN
toolchain__tool__installers() {
  @arr __toolchain__tool__installers__acc

  @join __toolchain__tool__installers__join_1 "$(kinds__names tool)" ' '
  for __toolchain__tool__installers__name in $__toolchain__tool__installers__join_1; do
    if @is_true "$(kinds__answers tool "$__toolchain__tool__installers__name" install)"; then
      @wrap __toolchain__tool__installers__wrap_2 "$__toolchain__tool__installers__name"
      @push __toolchain__tool__installers__acc \
        "$__toolchain__tool__installers__acc" \
        "$__toolchain__tool__installers__wrap_2"
    fi
  done

  println "$__toolchain__tool__installers__acc"
}

: <<'PUB_FUN'
Prints true when a tool plugin is registered under <name>, false otherwise.
PUB_FUN
toolchain__tool__registered() {
  kinds__registered tool "$1"
}

: <<'PUB_FUN'
Prints true when a tool plugin is registered under <name> and answers
<role>, false when none is or it leaves that role out.

    toolchain__tool__answers cursor-agent installed  ->  true

Usage: toolchain__tool__answers <name> <role>
PUB_FUN
toolchain__tool__answers() {
  if @is_true "$(kinds__registered tool "$1")"; then
    kinds__answers tool "$1" "$2"
  else
    @false __toolchain__tool__answers__out
    println "$__toolchain__tool__answers__out"
  fi
}

: <<'PUB_FUN'
Prints the tool plugin <name>'s @summary, one line.
PUB_FUN
toolchain__tool__summary() {
  kinds__call tool "$1" summary
}

: <<'PUB_FUN'
Runs the tool plugin <name>'s @install over <requirements>, returning what
it returns.

Usage: toolchain__tool__install <name> <requirements>
PUB_FUN
toolchain__tool__install() {
  kinds__call tool "$1" install "$2"
}

: <<'PUB_FUN'
Runs the tool plugin <name>'s @uninstall over <requirements>, returning
what it returns.

Usage: toolchain__tool__uninstall <name> <requirements>
PUB_FUN
toolchain__tool__uninstall() {
  kinds__call tool "$1" uninstall "$2"
}

: <<'PUB_FUN'
Prints the tool plugin <name>'s @installed over <requirements>: true when
the pinned version is installed, false otherwise. Fails when the plugin
leaves the role out; ask toolchain__tool__answers first.

Usage: toolchain__tool__installed <name> <requirements>
PUB_FUN
toolchain__tool__installed() {
  kinds__call tool "$1" installed "$2"
}

: <<'FUN'
Succeeds quietly when every registered tool plugin answers @install and
@uninstall together or neither; otherwise names each one that answers one
without the other, and returns 1.
FUN
__toolchain__tool__assert_installers() {
  __toolchain__tool__assert_installers__status=0

  @join __toolchain__tool__assert_installers__join_3 "$(kinds__names tool)" ' '
  for __toolchain__tool__assert_installers__name in $__toolchain__tool__assert_installers__join_3; do
    __toolchain__tool__assert_installer "$__toolchain__tool__assert_installers__name" \
      || __toolchain__tool__assert_installers__status=1
  done

  return "$__toolchain__tool__assert_installers__status"
}

: <<'FUN'
Succeeds quietly when the tool plugin <name> answers @install and
@uninstall together or neither; otherwise says which it lacks, and returns
1.

    __toolchain__tool__assert_installer gappy
      # ERROR: tool gappy answers install without uninstall; an installer answers both
FUN
__toolchain__tool__assert_installer() {
  __toolchain__tool__assert_installer__install="$(kinds__answers tool "$1" install)"
  __toolchain__tool__assert_installer__uninstall="$(kinds__answers tool "$1" uninstall)"

  if [ "$__toolchain__tool__assert_installer__install" = "$__toolchain__tool__assert_installer__uninstall" ]; then
    return 0
  fi

  if @is_true "$__toolchain__tool__assert_installer__install"; then
    error "tool $1 answers install without uninstall; an installer answers both"
  else
    error "tool $1 answers uninstall without install; an installer answers both"
  fi
  return 1
}

toolchain__tool__load_all "$SHELLOPS_DIR/lib"
