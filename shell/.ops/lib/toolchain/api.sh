#!/bin/sh

: <<'MODULE'
The toolchain: the tools a project's ops.lock files pin, and what one of
those tools means once its channel has been registered.

Most functions here take the resolver, the object ops install keeps its
state in: .registry holds one entry per tool and .channels holds what each
channel plugin registered. toolchain__order takes the registry alone, because an
order is a fact about the tools and what they need.

A whole lock file, a whole directory of scripts and a whole dependency walk
each take one call, so the cost of resolving a project's tools does not
grow with the number of tools in it.
MODULE

__toolchain__DIR="$SHELLOPS_DIR/lib/toolchain"

: <<'PUB_FUN'
The resolver with the tools <lock> names layered onto its registry. Each
entry gains the channel it was listed under and <origin_dir>, the directory
the lock was read from, which is what a postinstall script's path is
relative to. A tool the registry already holds takes the lock's entry
whole, so a lock layered later wins the tools both name.

args:
  $1  The resolver
  $2  The lock, as a struct
  $3  The directory the lock was read from
PUB_FUN
toolchain__with_lock() {
  @run_awk __toolchain__with_lock__out "$__toolchain__DIR/with_lock.awk" "$1" \
    --load "$__toolchain__DIR/resolver.awk" \
    --with "$2" \
    --arg origin_dir "$3" || return 1
  println "$__toolchain__with_lock__out"
}

: <<'PUB_FUN'
The registry's tools in dependency order -- every tool after the tools it
needs -- as {order}, or as {error} naming the first circular dependency or
unregistered need the walk meets.

  toolchain__order '{"a":{"needs":["b"]},"b":{}}'  ->  {"order":["b","a"]}
PUB_FUN
toolchain__order() {
  @run_awk __toolchain__order__out "$__toolchain__DIR/order.awk" "$1" \
    --load "$__toolchain__DIR/names.awk" || return 1
  println "$__toolchain__order__out"
}

: <<'PUB_FUN'
The resolver with each tool's installer and uninstaller script path recorded
on its registry entry, and every complaint about a script channel tool with
no plugin and no script, or a script with no counterpart, as {resolver,
errors}. A tool a registered tool plugin provisions needs no scripts. A
script naming a tool the registry does not hold records nothing and is
complained about.

args:
  $1  The resolver
  $2  The names of the tools a plugin provisions, as a struct array
  $3  The installer script paths, one per line, the winning ones last
  $4  The uninstaller script paths, one per line, the winning ones last
  $5  The directory a complaint names as the place a script belongs
PUB_FUN
toolchain__with_scripts() {
  @run_awk __toolchain__with_scripts__out "$__toolchain__DIR/script_paths.awk" "$1" \
    --load "$__toolchain__DIR/names.awk" \
    --load "$__toolchain__DIR/resolver.awk" \
    --with "$2" \
    --arg installers "$3" \
    --arg uninstallers "$4" \
    --arg scripts_dir "$5" || return 1
  println "$__toolchain__with_scripts__out"
}

: <<'PUB_FUN'
The resolver with <need> recorded among <tool>'s needs, left as it is when
the need is already there.

args:
  $1  The resolver
  $2  The tool the need belongs to
  $3  The tool it needs
PUB_FUN
toolchain__with_need() {
  @run_awk __toolchain__with_need__out "$__toolchain__DIR/with_need.awk" "$1" \
    --load "$__toolchain__DIR/resolver.awk" \
    --arg tool "$2" \
    --arg need "$3" || return 1
  println "$__toolchain__with_need__out"
}

: <<'PUB_FUN'
One tool's row: its registry entry read field by field, as {tool, entry,
channel, version, override, postinstall, origin_dir}. Bind it with @let and
a caller has every field it reads about a tool for one call. A tool the
registry does not name leaves the fields it would have filled null, which
@let binds as the empty string.

args:
  $1  The resolver
  $2  The tool
PUB_FUN
toolchain__row() {
  @run_awk __toolchain__row__out "$__toolchain__DIR/row.awk" "$1" --arg tool "$2" || return 1
  println "$__toolchain__row__out"
}

: <<'PUB_FUN'
Every tool of the resolver's registry whose channel names a dependency,
paired with the tool that dependency is, in the registry's key order.

  toolchain__channel_needs "$resolver"
    ->  [{"tool":"eza","dependency":"cargo-binstall"}]
PUB_FUN
toolchain__channel_needs() {
  @run_awk __toolchain__channel_needs__out "$__toolchain__DIR/channel_needs.awk" "$1" \
    --load "$__toolchain__DIR/names.awk" || return 1
  println "$__toolchain__channel_needs__out"
}
