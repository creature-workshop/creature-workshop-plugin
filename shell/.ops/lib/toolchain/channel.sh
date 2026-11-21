#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/kinds/api.sh" \
  "$SHELLOPS_DIR/lib/toolchain/tool.sh"

: <<'MODULE'
The channel kind: how ops install provisions a tool, chosen by the channel
its ops.lock entry sits under.

A channel is a tool that installs other tools, so the kind is a superset of
the tool kind (lib/toolchain/tool.sh): a channel plugin answers the tool
roles about itself, and these about the tools it installs. It is a file
named <name>.channel.op.sh defining @channel.<name>() with:

  @summary                        What the channel installs, in one line.
  @aliases                        Other names a lock may use for this
                                  channel, as a struct array.
  @install_tool <tool> <entry>    Provisions the tool from its ops.lock
                                  entry. Non-zero fails it.
  @uninstall_tool <tool> <entry>  Removes the tool.
  @probe <tool> <entry>           Prints true when the tool is installed,
                                  false otherwise. A channel that leaves it
                                  out has its tools judged by a command of
                                  their name being on PATH.
  @activate <tool> <entry>        Run for a tool the probe found installed,
                                  in place of the installer, for a channel
                                  whose installed tools still record their
                                  environment in the checkout.
  @dependency                     The tool this channel is: rustup for
                                  cargo-install, node for npm. Every tool
                                  of the channel needs it first.
  @dependency_default             The lock entry that registers the
                                  dependency when no lock names it.
  @install, @uninstall,           The tool roles, about the channel itself.
  @installed <entry>              A channel that leaves @installed out is
                                  installed when its dependency is on PATH,
                                  and always when it names none: the
                                  script channel needs only sh.

A plugin sits beside the module it installs through, lib/node/
npm.channel.op.sh for npm, and importing this module loads every one under
lib/; a project's own load from its channels directory when ops install
asks. A lock names a channel by its plugin name or by an alias the plugin
declares, and every function here takes either.
MODULE

__toolchain__channel__ROLES="$__toolchain__tool__ROLES aliases install_tool uninstall_tool probe activate dependency dependency_default"
__toolchain__channel__REQUIRED="install_tool uninstall_tool"

: <<'CONST'
Every alias any loaded channel declares, as space-joined <alias>=<name>
pairs in load order. An alias holds no whitespace and no equals sign, so a
read splits exactly.
CONST
__toolchain__channel__ALIASES=""

: <<'PUB_FUN'
Loads and registers the channel plugin <name>, whose file has been
imported, and records the aliases it declares. See kinds__load.
PUB_FUN
toolchain__channel__load() {
  kinds__load channel "$1" "$__toolchain__channel__ROLES" "$__toolchain__channel__REQUIRED" \
    || return 1
  __toolchain__channel__record_aliases "$1"
}

: <<'PUB_FUN'
Finds and loads every channel plugin under <root>, recording their aliases;
a root that is not a directory holds none. See kinds__scan.
PUB_FUN
toolchain__channel__load_all() {
  if [ ! -d "$1" ]; then
    return 0
  fi

  kinds__scan channel "$1" "$__toolchain__channel__ROLES" "$__toolchain__channel__REQUIRED" \
    || return 1
  @foreach __toolchain__channel__record_wrapped_aliases "$(kinds__names channel)"
}

: <<'FUN'
@foreach callback: records the aliases of the wrapped channel <name>.
FUN
__toolchain__channel__record_wrapped_aliases() {
  @unwrap __toolchain__channel__record_wrapped_aliases__unwrap_1 "$1"
  __toolchain__channel__record_aliases "$__toolchain__channel__record_wrapped_aliases__unwrap_1"
}

: <<'FUN'
Records each alias the channel <name> declares, once: a channel loaded
twice records nothing the second time.
FUN
__toolchain__channel__record_aliases() {
  if ! @is_true "$(kinds__answers channel "$1" aliases)"; then
    return 0
  fi

  @join __toolchain__channel__record_aliases__join_2 "$(kinds__call channel "$1" aliases)" ' '
  for __toolchain__channel__record_aliases__alias in $__toolchain__channel__record_aliases__join_2; do
    __toolchain__channel__record_alias "$__toolchain__channel__record_aliases__alias" "$1"
  done
}

: <<'FUN'
Records that <alias> names the channel <name>, unless it already does.
FUN
__toolchain__channel__record_alias() {
  case " $__toolchain__channel__ALIASES " in
    *" $1=$2 "*) return 0 ;;
  esac
  __toolchain__channel__ALIASES="${__toolchain__channel__ALIASES:+$__toolchain__channel__ALIASES }$1=$2"
}

: <<'PUB_FUN'
Prints the plugin name the channel <name> resolves to: the name itself, or
the plugin an alias of that name was declared by. A name no plugin carries
prints as itself, so the call that follows refuses it by that name.

    toolchain__channel__plugin_of local  ->  script
PUB_FUN
toolchain__channel__plugin_of() {
  for __toolchain__channel__plugin_of__pair in $__toolchain__channel__ALIASES; do
    if [ "${__toolchain__channel__plugin_of__pair%%=*}" = "$1" ]; then
      println "${__toolchain__channel__plugin_of__pair#*=}"
      return 0
    fi
  done

  println "$1"
}

: <<'PUB_FUN'
Prints the names of every channel plugin, as a struct array, in load order.
Aliases are not among them.
PUB_FUN
toolchain__channel__names() {
  kinds__names channel
}

: <<'PUB_FUN'
Prints the names and aliases every lock may name a channel by, as a struct
array: the plugin names in load order, then the aliases in the order they
were declared.
PUB_FUN
toolchain__channel__known_names() {
  __toolchain__channel__known_names__names="$(kinds__names channel)"

  for __toolchain__channel__known_names__pair in $__toolchain__channel__ALIASES; do
    @push __toolchain__channel__known_names__names \
      "$__toolchain__channel__known_names__names" \
      "${__toolchain__channel__known_names__pair%%=*}"
  done

  println "$__toolchain__channel__known_names__names"
}

: <<'PUB_FUN'
Prints true when a lock may name a channel <name>: a plugin is registered
under it, or an alias declares it. False otherwise.
PUB_FUN
toolchain__channel__known() {
  kinds__registered channel "$(toolchain__channel__plugin_of "$1")"
}

: <<'PUB_FUN'
Prints true when the channel <name> is known and answers <role>, false when
it is unknown or leaves that role out.

    toolchain__channel__answers npm probe  ->  true

Usage: toolchain__channel__answers <name> <role>
PUB_FUN
toolchain__channel__answers() {
  __toolchain__channel__answers__plugin="$(toolchain__channel__plugin_of "$1")"

  if @is_true "$(kinds__registered channel "$__toolchain__channel__answers__plugin")"; then
    kinds__answers channel "$__toolchain__channel__answers__plugin" "$2"
  else
    @false __toolchain__channel__answers__out
    println "$__toolchain__channel__answers__out"
  fi
}

: <<'PUB_FUN'
Prints the channel <name>'s @summary, one line.
PUB_FUN
toolchain__channel__summary() {
  kinds__call channel "$(toolchain__channel__plugin_of "$1")" summary
}

: <<'PUB_FUN'
Runs the channel <name>'s @install_tool over <tool> and <entry>, returning
what it returns. Fails, naming the known channels, when the name is
unknown.

Usage: toolchain__channel__install_tool <name> <tool> <entry>
PUB_FUN
toolchain__channel__install_tool() {
  kinds__call channel "$(toolchain__channel__plugin_of "$1")" install_tool "$2" "$3"
}

: <<'PUB_FUN'
Runs the channel <name>'s @uninstall_tool over <tool> and <entry>,
returning what it returns.

Usage: toolchain__channel__uninstall_tool <name> <tool> <entry>
PUB_FUN
toolchain__channel__uninstall_tool() {
  kinds__call channel "$(toolchain__channel__plugin_of "$1")" uninstall_tool "$2" "$3"
}

: <<'PUB_FUN'
Prints true when the channel <name> is itself installed and can provision
tools: as its @installed judges when it answers one, otherwise by a
command named after its dependency being on PATH, and always for a
channel that names no dependency.

    toolchain__channel__installed npm  ->  true, once node is on PATH
PUB_FUN
toolchain__channel__installed() {
  __toolchain__channel__installed__dependency="$(toolchain__channel__dependency "$1")"

  if @is_true "$(toolchain__channel__answers "$1" installed)"; then
    kinds__call channel "$(toolchain__channel__plugin_of "$1")" installed
  elif @defined "$__toolchain__channel__installed__dependency"; then
    @succeeds __toolchain__channel__installed__out __toolchain__channel__on_path "$__toolchain__channel__installed__dependency"
    println "$__toolchain__channel__installed__out"
  else
    @true __toolchain__channel__installed__out
    println "$__toolchain__channel__installed__out"
  fi
}

: <<'PUB_FUN'
Succeeds quietly when the channel <name> is installed; otherwise says what
it needs and what installs it, and returns 1.

    toolchain__channel__assert_installed npm
      # ERROR: channel npm needs node; install with ops install node
PUB_FUN
toolchain__channel__assert_installed() {
  if @is_true "$(toolchain__channel__installed "$1")"; then
    return 0
  fi

  __toolchain__channel__assert_installed__dependency="$(toolchain__channel__dependency "$1")"
  error "channel $1 needs $__toolchain__channel__assert_installed__dependency; install with ops install $__toolchain__channel__assert_installed__dependency"
  return 1
}

: <<'FUN'
Succeeds quietly when a command named <name> is on PATH.
FUN
__toolchain__channel__on_path() {
  command -v "$1" >/dev/null 2>&1
}

: <<'PUB_FUN'
Prints the channel <name>'s @probe over <tool> and <entry>: true when the
tool is installed, false otherwise. Fails when the channel leaves the role
out; ask toolchain__channel__answers first.

Usage: toolchain__channel__probe <name> <tool> <entry>
PUB_FUN
toolchain__channel__probe() {
  kinds__call channel "$(toolchain__channel__plugin_of "$1")" probe "$2" "$3"
}

: <<'PUB_FUN'
Runs the channel <name>'s @activate over the installed <tool> and its
<entry>, returning what it returns. Fails when the channel leaves the role
out; ask toolchain__channel__answers first.

Usage: toolchain__channel__activate <name> <tool> <entry>
PUB_FUN
toolchain__channel__activate() {
  kinds__call channel "$(toolchain__channel__plugin_of "$1")" activate "$2" "$3"
}

: <<'PUB_FUN'
Prints the tool every tool of the channel <name> needs first, or nothing
for a channel that names none.

    toolchain__channel__dependency npm  ->  node
PUB_FUN
toolchain__channel__dependency() {
  if @is_true "$(toolchain__channel__answers "$1" dependency)"; then
    kinds__call channel "$(toolchain__channel__plugin_of "$1")" dependency
  fi
}

: <<'PUB_FUN'
Prints the lock entry that registers the channel <name>'s dependency when
no lock names it, or nothing for a channel that declares none.
PUB_FUN
toolchain__channel__dependency_default() {
  if @is_true "$(toolchain__channel__answers "$1" dependency_default)"; then
    kinds__call channel "$(toolchain__channel__plugin_of "$1")" dependency_default
  fi
}

: <<'PUB_FUN'
Prints what every loaded channel obliges its tools to, as a struct object
keyed by every name and alias a lock may use: the dependency and the
dependency default each declares, and an empty object for a channel that
declares neither. The resolver carries this under .channels, so the
toolchain's awk programs join a tool to its channel's needs in one read.

    toolchain__channel__table
      ->  {"npm":{"dependency":"node"},"script":{},"local":{}, ...}
PUB_FUN
toolchain__channel__table() {
  @obj __toolchain__channel__table__obj_3
  @reduce __toolchain__channel__table__out __toolchain__channel__table_row "$(toolchain__channel__known_names)" "$__toolchain__channel__table__obj_3"
  println "$__toolchain__channel__table__out"
}

: <<'FUN'
@reduce callback: adds the wrapped channel <name>'s row to the table.
FUN
__toolchain__channel__table_row() {
  @unwrap __toolchain__channel__table_row__name "$2"
  @obj __toolchain__channel__table_row__row
  __toolchain__channel__table_row__dependency="$(toolchain__channel__dependency "$__toolchain__channel__table_row__name")"
  __toolchain__channel__table_row__default="$(toolchain__channel__dependency_default "$__toolchain__channel__table_row__name")"

  if @defined "$__toolchain__channel__table_row__dependency"; then
    @set __toolchain__channel__table_row__row "$__toolchain__channel__table_row__row" \
      '.dependency' "$__toolchain__channel__table_row__dependency"
  fi

  if @defined "$__toolchain__channel__table_row__default"; then
    @set __toolchain__channel__table_row__row "$__toolchain__channel__table_row__row" \
      '.dependency_default' "$__toolchain__channel__table_row__default"
  fi

  @set __toolchain__channel__table_row__out "$1" ".\"$__toolchain__channel__table_row__name\"" "$__toolchain__channel__table_row__row"
  println "$__toolchain__channel__table_row__out"
}

toolchain__channel__load_all "$SHELLOPS_DIR/lib"
