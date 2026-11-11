#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/args/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Plugin kinds: what every kind of plugin shares, so a kind is its name, its
contract and nothing else.

A plugin of kind <kind> is a file named <name>.<kind>.op.sh defining one
function, @<kind>.<name>(), whose inner @-functions are its roles. Loading it
(kinds__load) turns each role into a plain function <prefix>_<role>, where
<prefix> is the name with dashes turned to underscores, checks the required
roles exist, and adds the name to the kind's list. kinds__scan finds every
plugin of a kind under a root and loads it; nothing lists plugins anywhere.

A plugin may spell its roles as those plain functions itself, <prefix>_<role>
inside @<kind>.<name>(), and load with kinds__load_flat, which calls the
outer, checks the required roles and adds the name, re-homing nothing: any
POSIX shell, no subprocess. A module declaring a plugin at run time, as
@enum declares a type, defines the plain functions and calls kinds__register;
a plugin spelled with inner @<role>() functions is lowered to them first by
kinds__lower (lower.sh), which ops compile runs.

Every plugin may declare @needs, the programs it runs, as a struct array; a
kind's contract need not mention it. kinds__assert_needs holds a plugin to
them before it runs, naming what to install when one is off the PATH; the
installing is a program boundary's work, never a plugin's or its kind's.

A kind's own module names its roles, says what each means, and wraps these
in its own words (lib/profile/api.sh is one).

The registry is one variable per kind, __kinds__NAMES__<kind>, its plugins'
names space-joined in load order. Names hold no whitespace, so load appends
and read splits with no subprocess; a scan costs the loads, a call the call.
MODULE

: <<'PUB_FUN'
Prints the function prefix a plugin's roles live under: its name with dashes
turned to underscores.

    kinds__prefix fork-tree  ->  fork_tree
PUB_FUN
kinds__prefix() {
  __kinds__prefix "$1"
  println "$__kinds__prefix__prefix"
}

: <<'FUN'
Sets __kinds__prefix__prefix to the function prefix of the plugin <name>:
what kinds__prefix prints, for the callers inside the module that must not
start a subshell to read it.
FUN
__kinds__prefix() {
  __kinds__prefix__rest="$1"
  __kinds__prefix__prefix=""
  while [ "$__kinds__prefix__rest" != "${__kinds__prefix__rest#*-}" ]; do
    __kinds__prefix__prefix="$__kinds__prefix__prefix${__kinds__prefix__rest%%-*}_"
    __kinds__prefix__rest="${__kinds__prefix__rest#*-}"
  done
  __kinds__prefix__prefix="$__kinds__prefix__prefix$__kinds__prefix__rest"
}

: <<'PUB_FUN'
Prints the name of the plain function that is <role> for the plugin <name>.

    kinds__fn forks run  ->  forks_run

Usage: kinds__fn <name> <role>
PUB_FUN
kinds__fn() {
  __kinds__fn "$1" "$2"
  println "$__kinds__fn__name"
}

: <<'FUN'
Sets __kinds__fn__name to what kinds__fn prints for the plugin <name> and
<role>, without a subshell.
FUN
__kinds__fn() {
  __kinds__prefix "$1"
  __kinds__fn__name="${__kinds__prefix__prefix}_$2"
}

: <<'PUB_FUN'
Loads and registers the plugin <name> of kind <kind>, whose file has been
imported. Does nothing when it is already registered, so importing a plugin
twice is harmless. Fails, saying which role is missing, when the plugin does
not answer the required roles.

args:
  $1  The kind
  $2  The plugin name
  $3  The space-separated roles the kind knows
  $4  The space-separated roles the kind requires
PUB_FUN
kinds__load() {
  if __kinds__is_registered "$1" "$2"; then
    return 0
  fi

  command -v interpreter__load_kind >/dev/null 2>&1 \
    || import "$SHELLOPS_DIR/interpreter/api.sh"
  interpreter__load_kind "$1" "$2" "@$1.$2" "$3" "$4" \
    || return 1

  __kinds__append "$1" "$2"
}

: <<'PUB_FUN'
Loads and registers the plugin <name> of kind <kind>, whose file has been
imported and whose outer function @<kind>.<name>() defines its roles as the
plain functions <prefix>_<role> itself. Calls the outer function, checks
the required roles are defined and adds the name to the kind's list,
re-homing nothing: the load runs in any POSIX shell and starts no
subprocess. Does nothing when the plugin is already registered. Fails,
saying which, when the plugin is not defined or leaves a required role out.

args:
  $1  The kind
  $2  The plugin name
  $3  The space-separated roles the kind requires
PUB_FUN
kinds__load_flat() {
  if __kinds__is_registered "$1" "$2"; then
    return 0
  fi

  if ! __kinds__is_defined "@$1.$2"; then
    error "kinds: no plugin @$1.$2 is defined"
    return 1
  fi

  "@$1.$2" || return 1
  kinds__register "$1" "$2" "$3"
}

: <<'PUB_FUN'
Registers <name> as a plugin of kind <kind> whose roles are defined already
as the plain functions <prefix>_<role>: what a load ends with, for a plugin
a module declares at run time (@enum declares a type this way). Does
nothing when the name is registered. Fails, naming the role, when a
required one is not defined.

args:
  $1  The kind
  $2  The plugin name
  $3  The space-separated roles the kind requires
PUB_FUN
kinds__register() {
  if __kinds__is_registered "$1" "$2"; then
    return 0
  fi

  __kinds__require_defined "$1" "$2" "$3" || return 1
  __kinds__append "$1" "$2"
}

: <<'FUN'
Succeeds quietly when the plugin <name> of kind <kind> defines every role in
the space-separated <roles> as its plain function; otherwise says which is
missing and returns 1.
FUN
__kinds__require_defined() {
  for __kinds__require_defined__role in $3; do
    __kinds__fn "$2" "$__kinds__require_defined__role"
    if ! __kinds__is_defined "$__kinds__fn__name"; then
      error "kinds: $1 $2 does not define $__kinds__require_defined__role"
      return 1
    fi
  done
  return 0
}

: <<'FUN'
Adds the plugin <name> to the list of kind <kind>, after the names loaded
before it.
FUN
__kinds__append() {
  __kinds__words "$1"
  eval "__kinds__NAMES__$1=\"\${__kinds__words__words:+\$__kinds__words__words }\$2\""
}

: <<'PUB_FUN'
Prints true when a plugin <name> of kind <kind> is registered, false
otherwise.

Usage: kinds__registered <kind> <name>
PUB_FUN
kinds__registered() {
  if __kinds__is_registered "$1" "$2"; then
    @true __kinds__registered__out
    println "$__kinds__registered__out"
  else
    @false __kinds__registered__out
    println "$__kinds__registered__out"
  fi
}

: <<'FUN'
Succeeds quietly when a plugin <name> of kind <kind> is registered: the
check the module makes on every load and call, so it starts no subshell.
FUN
__kinds__is_registered() {
  __kinds__words "$1"
  for __kinds__is_registered__name in $__kinds__words__words; do
    if [ "$__kinds__is_registered__name" = "$2" ]; then
      return 0
    fi
  done
  return 1
}

: <<'FUN'
Sets __kinds__words__words to the names of every registered plugin of kind
<kind>, space-joined in load order, or to nothing for a kind nothing has
loaded.
FUN
__kinds__words() {
  eval "__kinds__words__words=\"\${__kinds__NAMES__$1:-}\""
}

: <<'PUB_FUN'
Prints true when any plugin of kind <kind> is registered, false otherwise:
whether the kind exists at all.
PUB_FUN
kinds__known() {
  __kinds__words "$1"
  if [ -n "$__kinds__words__words" ]; then
    @true __kinds__known__out
    println "$__kinds__known__out"
  else
    @false __kinds__known__out
    println "$__kinds__known__out"
  fi
}

: <<'PUB_FUN'
Prints the names of every registered plugin of kind <kind>, as a struct
array, in the order they loaded. Empty for a kind nothing has loaded.
PUB_FUN
kinds__names() {
  __kinds__words "$1"
  # A name holds no whitespace and no glob character, so splitting is exact.
  # shellcheck disable=SC2086
  set -- $__kinds__words__words
  @arr __kinds__names__out "$@"
  println "$__kinds__names__out"
}

: <<'PUB_FUN'
Calls the role <role> of the plugin <name> of kind <kind> with the arguments
after them, returning what it returns. Fails, naming the known plugins, when
the kind or the plugin is unknown, and naming the role when the plugin
leaves it out, so a caller never reaches for a function that is not there.

Usage: kinds__call <kind> <name> <role> [args...]
PUB_FUN
kinds__call() {
  __kinds__call__kind="$1"
  __kinds__call__name="$2"
  __kinds__call__role="$3"
  shift 3

  kinds__require_known "$__kinds__call__kind" "$__kinds__call__name" || return 1
  __kinds__fn "$__kinds__call__name" "$__kinds__call__role"
  if ! __kinds__is_defined "$__kinds__fn__name"; then
    error "$__kinds__call__name does not answer $__kinds__call__role"
    return 1
  fi
  "$__kinds__fn__name" "$@"
}

: <<'PUB_FUN'
Prints true when the registered plugin <name> of kind <kind> answers <role>,
false when it leaves that role out; how a kind asks an optional role before
calling it. Fails, saying which is unknown, when the plugin is not
registered.

    kinds__answers promotion shellops sites  ->  true

Usage: kinds__answers <kind> <name> <role>
PUB_FUN
kinds__answers() {
  kinds__require_known "$1" "$2" || return 1
  __kinds__fn "$2" "$3"
  @succeeds __kinds__answers__out __kinds__is_defined "$__kinds__fn__name"
  println "$__kinds__answers__out"
}

: <<'FUN'
Succeeds quietly when a function named <name> is defined.
FUN
__kinds__is_defined() {
  command -v "$1" > /dev/null 2>&1
}

: <<'PUB_FUN'
Succeeds quietly when the plugin <name> of kind <kind> is registered;
otherwise says which is unknown, the kind or the plugin, names the plugins
the kind has, and returns 1.

Usage: kinds__require_known <kind> <name> || exit 1
PUB_FUN
kinds__require_known() {
  if __kinds__is_registered "$1" "$2"; then
    return 0
  fi

  __kinds__words "$1"
  if [ -z "$__kinds__words__words" ]; then
    error "Unknown kind: $1"
    return 1
  fi

  error "Unknown $1: $2"
  @join __kinds__require_known__join_1 "$(kinds__names "$1")" ' '
  hint "Expected one of: $__kinds__require_known__join_1"
  return 1
}

: <<'PUB_FUN'
Succeeds quietly when every program the plugin <name> of kind <kind> declares
in @needs is on the PATH, and for a plugin that declares none. Otherwise says
what is missing and what installs it, and returns 1.

    kinds__assert_needs profile forks   # ERROR: forks needs strace; install with ops install strace

Usage: kinds__assert_needs <kind> <name> || exit 1
PUB_FUN
kinds__assert_needs() {
  __kinds__assert_needs__missing="$(__kinds__needs_missing "$1" "$2")"
  if @len __kinds__assert_needs__len_2 "$__kinds__assert_needs__missing"; [ "$__kinds__assert_needs__len_2" -eq 0 ]; then
    return 0
  fi

  @join __kinds__assert_needs__names "$__kinds__assert_needs__missing" ' '
  error "$2 needs $__kinds__assert_needs__names; install with ops install $__kinds__assert_needs__names"
  return 1
}

: <<'FUN'
Prints the programs the plugin <name> of kind <kind> declares in @needs that
are not on the PATH, as a struct array. Empty when the plugin can run, and
for a plugin that declares no needs.
FUN
__kinds__needs_missing() {
  @arr __kinds__needs_missing__arr_3
  @reduce __kinds__needs_missing__out __kinds__collect_missing "$(__kinds__needs "$1" "$2")" "$__kinds__needs_missing__arr_3"
  println "$__kinds__needs_missing__out"
}

: <<'FUN'
Prints the programs the plugin <name> of kind <kind> declares in @needs, as
a struct array; empty for a plugin that declares none.
FUN
__kinds__needs() {
  __kinds__fn "$2" needs
  __kinds__needs__fn="$__kinds__fn__name"
  if command -v "$__kinds__needs__fn" >/dev/null 2>&1; then
    "$__kinds__needs__fn"
  else
    @arr __kinds__needs__out
    println "$__kinds__needs__out"
  fi
}


: <<'FUN'
@reduce callback: adds the wrapped <program> to the accumulator unless it is
on the PATH.
FUN
__kinds__collect_missing() {
  @unwrap __kinds__collect_missing__program "$2"

  if command -v "$__kinds__collect_missing__program" >/dev/null 2>&1; then
    println "$1"
  else
    @push __kinds__collect_missing__out "$1" "$__kinds__collect_missing__program"
    println "$__kinds__collect_missing__out"
  fi
}

: <<'PUB_FUN'
Finds every <name>.<kind>.op.sh under <root>, imports each and loads the
plugin it defines under the name its filename carries, in sorted path order,
so a list reads the same on every machine. Fails when a plugin does not load.

args:
  $1  The kind
  $2  The root to search
  $3  The space-separated roles the kind knows
  $4  The space-separated roles the kind requires
PUB_FUN
kinds__scan() {
  __kinds__scan __kinds__load_one "$1" "$2" "$3" "$4"
}

: <<'PUB_FUN'
Finds every <name>.<kind>.op.sh under <root>, imports each and loads the
plugin it defines with kinds__load_flat, in sorted path order. Fails when a
plugin does not load.

args:
  $1  The kind
  $2  The root to search
  $3  The space-separated roles the kind requires
PUB_FUN
kinds__scan_flat() {
  __kinds__scan __kinds__load_one_flat "$1" "$2" "" "$3"
}

: <<'FUN'
Finds every plugin file of kind $2 under $3 and hands each to the loader
$1 in sorted path order, with the roles $4 the kind knows and the roles $5
it requires.
FUN
__kinds__scan() {
  __kinds__scan__files="$(
    find "$3" -name "*.$2.op.sh" \
      | LC_ALL=C sort
  )"

  args__call_with_lines __kinds__load_each "$__kinds__scan__files" "$1" "$2" "$4" "$5"
}

: <<'FUN'
Hands each plugin file to the loader, one after the other. Runs in the
importing shell, not a pipeline, so the functions a plugin defines stay
defined. A plugin's import may scan another kind on the way in, so the walk
keeps its place in its own positionals, which a nested scan cannot touch,
and never in a variable both scans would share.

args:
  $1  The loader, __kinds__load_one or __kinds__load_one_flat
  $2  The kind
  $3  The roles the kind knows
  $4  The roles the kind requires
  $@  The plugin files
FUN
__kinds__load_each() {
  if [ "$#" -le 4 ]; then
    return 0
  fi

  "$1" "$2" "$3" "$4" "$5" || return 1

  __kinds__load_each__loader="$1"
  __kinds__load_each__kind="$2"
  __kinds__load_each__roles="$3"
  __kinds__load_each__required="$4"
  shift 5
  __kinds__load_each \
    "$__kinds__load_each__loader" \
    "$__kinds__load_each__kind" \
    "$__kinds__load_each__roles" \
    "$__kinds__load_each__required" \
    "$@"
}

: <<'FUN'
Imports the plugin file $4 and loads the plugin it defines as kind $1, with
the roles $2 the kind knows and the roles $3 it requires.
FUN
__kinds__load_one() {
  import "$4" || return 1
  kinds__load "$1" "$(kinds__name_of "$1" "$4")" "$2" "$3"
}

: <<'FUN'
Imports the plugin file $4 and loads the plugin it defines as kind $1 with
kinds__load_flat, with the roles $3 the kind requires; $2 is the roles the
kind knows, which a plain-function plugin does not need.
FUN
__kinds__load_one_flat() {
  import "$4" || return 1
  kinds__load_flat "$1" "$(kinds__name_of "$1" "$4")" "$3"
}

: <<'PUB_FUN'
Prints the plugin name a file carries: its filename without the directory
and without the .<kind>.op.sh suffix.

    kinds__name_of profile lib/forks/forks.profile.op.sh  ->  forks

Usage: kinds__name_of <kind> <file>
PUB_FUN
kinds__name_of() {
  __kinds__name_of__base="${2##*/}"
  printf '%s\n' "${__kinds__name_of__base%."$1".op.sh}"
}
