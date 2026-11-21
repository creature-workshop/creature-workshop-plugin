#!/bin/sh

: <<'MODULE'
The pins, .ops/cache/pins.sh: where each git dependency's tree is, derived
from the lock and sourced by .envrc, one exported variable per repository
(ADR 000049, ADR 000050). The boot reads the lock's git entries by walking
the lock's nesting in awk, makes each tree present, mounts the ones a
dependency pins as submodules, removes the trees the lock no longer
names, and writes the pins file, so a first boot fetches every tree before
the structs library loads and a later shell pays one file test per tree.
A dependency the lock names as a tool and through another keeps both
trees: the tool's takes the variable, and the other is a mounted line.

A consumer runs on the run-time trees shellops' own lock names, strata
and shell-logs, from shellops' cache, whether or not its own lock names a
git dependency (ADR 000048): a consumer declares no strata. When its lock
names any, the consumer's trees are made present from its own cache after
shellops', and a name both locks carry is the consumer's.

A dependency is fetched from beside the repository that reached it, as
git resolves "../<name>.git": this repository's origin for a direct entry
naming no repository, the parent's for one reached through it, whatever
the parent declared. One lock then serves every host that holds the
siblings. <NAME>_URL in the environment names the repository instead.

Environment:
  The boot resolves a repository only for a tree that is absent, so a copy
  that has every tree needs no origin, no git repository and no network.
  The pins file records each tree relative to the directory the file is in,
  so a repository that is copied or moved with its cache boots on the pins
  file it has and writes nothing.

A tree the pins name carries the command <name> when it has an executable
cli/<name>. The ops dispatcher runs that command when shellops has no
cli/<name> of its own, so a tool the lock pins is run as `ops <name>` with
no wrapper in shellops. The first tree that carries the name provides it,
PROJ's trees before shellops' own.

  self__pins__ensure
    ->  .ops/cache/pins.sh:
          export SHELL_GOLDENS_DIR="$__self__pins__TREES/shell-goldens/0bed..."
          export STRATA_DIR="$__self__pins__TREES/strata/73e6..."
          # mounted: $__self__pins__TREES/shell-goldens/5cbd...
          export SHELL_LOGS_DIR="$__self__pins__TREES/shell-logs/7f3d..."
    ->  STRATA_DIR=/p/.ops/cache/strata/73e6...

  self__pins__command lint
    ->  /p/.ops/cache/shell-lint/6bb8.../cli/lint
MODULE

# CONST: The cache, relative to the repository whose lock the pins are derived from, where the trees go (ADR 000011).
__self__pins__CACHE='.ops/cache'

# CONST: The pins file, relative to the repository whose lock it is derived from.
__self__pins__FILE='.ops/cache/pins.sh'

# CONST: The lock, relative to a repository's root.
__self__pins__LOCK='.ops/lock'

# CONST: The awk that reads the lock's lines by nesting, loaded before every program over the lock.
__self__pins__LINES_AWK="$SHELLOPS_DIR/lib/self/lock/lines.awk"

# CONST: The awk that prints the lock's git entries.
__self__pins__AWK="$SHELLOPS_DIR/lib/self/pins.awk"

# shellcheck disable=SC2016  # the text is written into the pins file, and expanded when the file is sourced
# CONST: The text a pins file writes before each tree: the name of the variable below, which the shell expands when it sources the file.
__self__pins__TREES_REFERENCE='$__self__pins__TREES'

# shellcheck disable=SC2034  # read by the pins file when it is sourced
# CONST: The directory the pins file being sourced is in, which the trees it records are under.
__self__pins__TREES=""

# CONST: How the lock names the repository of each dependency pinned so far in one run, as "<name>=<repository>|<via>" words, so a child that has to be fetched finds its parent's.
__self__pins__SOURCES=""

# CONST: The commits pinned so far in one run, as "<name>=<commit>" words, so a child finds its parent's tree.
__self__pins__COMMITS=""

: <<'PUB_FUN'
Prints the cache the repository <root> keeps its git trees in.

  self__pins__cache /p   ->  /p/.ops/cache

args:
  $1  The repository's root
PUB_FUN
self__pins__cache() {
  println "$1/$__self__pins__CACHE"
}

: <<'PUB_FUN'
Sets __self__pins__root__dir to the repository whose lock names the git
dependencies this shell runs on: PROJ when its lock names any, and
shellops' own checkout otherwise. Sets a variable rather than printing,
so asking forks nothing.

Usage: self__pins__root
PUB_FUN
self__pins__root() {
  __self__pins__root__dir="$SHELLOPS_DIR"
  if [ -f "${PROJ:-}/$__self__pins__LOCK" ] && [ -n "$(self__pins__entries "$PROJ/$__self__pins__LOCK")" ]; then  # structs-lint: allow -- plain shell, loaded before structs
    __self__pins__root__dir="$PROJ"
  fi
}

: <<'PUB_FUN'
Sets __self__pins__own__dir to the tree shellops' own lock names for the
dependency <name>, read from shellops' pins file as self__pins__ensure
left it, whatever PROJ's lock names under the same name: what shellops
itself runs on, the SILT library among it (ADR 000048), is pinned by
shellops and not by the host. Empty when shellops' lock names no such
dependency. Sets a variable rather than printing, so the boot forks once,
for the variable's name, and not again.

  self__pins__own strata  ->  __self__pins__own__dir=/s/.ops/cache/strata/47a6...

Usage: self__pins__own <name>
PUB_FUN
self__pins__own() {
  __self__pins__own__dir=""
  __self__pins__own__file="$SHELLOPS_DIR/$__self__pins__FILE"
  [ -f "$__self__pins__own__file" ] || return 0  # structs-lint: allow -- plain shell, loaded before structs
  __self__pins__own__prefix="export $(__self__pins__variable "$1")=\""
  while IFS= read -r __self__pins__own__line; do
    case "$__self__pins__own__line" in
      "$__self__pins__own__prefix"*)
        __self__pins__own__recorded="${__self__pins__own__line#"$__self__pins__own__prefix"}"
        __self__pins__located "${__self__pins__own__file%/*}" "${__self__pins__own__recorded%\"}"
        __self__pins__own__dir="$__self__pins__located__dir"
        ;;
    esac
  done < "$__self__pins__own__file"
}

: <<'PUB_FUN'
Prints the git trees of the lock <lock>, one per line, as
"<name>|<commit>|<repository>|<via>|<mount>": the git channel's trees
first and the imports last. Prints nothing when the lock names none or
does not exist.

Usage: self__pins__entries <lock>
PUB_FUN
self__pins__entries() {
  [ -f "$1" ] || return 0
  awk -f "$__self__pins__LINES_AWK" -f "$__self__pins__AWK" "$1"
}

: <<'PUB_FUN'
Makes every git dependency present and exports a variable naming each
one's tree: the ones shellops' own lock names first, from shellops' cache,
and then the ones PROJ's lock names, from PROJ's cache, when it names any.
Each lock's pins file is written and sourced in that order, so a name both
locks carry is PROJ's. Does nothing when neither PROJ nor shellops has a
lock. Fails, saying which, when a tree cannot be fetched.

Usage: self__pins__ensure
PUB_FUN
self__pins__ensure() {
  self__pins__root
  if [ "$__self__pins__root__dir" != "$SHELLOPS_DIR" ]; then
    __self__pins__ensure_lock "$SHELLOPS_DIR" || return 1
  fi
  __self__pins__ensure_lock "$__self__pins__root__dir"
}

: <<'FUN'
Makes every git dependency the lock of the repository <root> names present
under its cache, writes its pins file when it is stale, and sources it.
Does nothing when the repository has no lock. Fails, saying which, when a
tree is absent and cannot be fetched.

Usage: __self__pins__ensure_lock <root>
FUN
__self__pins__ensure_lock() {
  __self__pins__ensure_lock__lock="$1/$__self__pins__LOCK"
  [ -f "$__self__pins__ensure_lock__lock" ] || return 0
  __self__pins__ensure_lock__file="$1/$__self__pins__FILE"

  if __self__pins__stale "$__self__pins__ensure_lock__lock" "$__self__pins__ensure_lock__file"; then
    __self__pins__write "$1" "$__self__pins__ensure_lock__lock" "$__self__pins__ensure_lock__file" || return 1
  fi
  # shellcheck disable=SC2034  # read by the pins file when it is sourced
  __self__pins__TREES="${__self__pins__ensure_lock__file%/*}"
  . "$__self__pins__ensure_lock__file"
}

: <<'FUN'
Succeeds when the pins file <file> has to be written again: it is absent,
the lock <lock> changed after it was written, or a tree it names is gone.

Usage: __self__pins__stale <lock> <file>
FUN
__self__pins__stale() {
  [ -f "$2" ] || return 0
  [ -z "$(find "$1" -newer "$2")" ] || return 0  # structs-lint: allow -- plain shell, loaded before structs
  ! __self__pins__trees_present "$2"
}

: <<'FUN'
Succeeds when every tree the pins file <file> names is present, and fails
when one is missing, so a cache that lost a tree is fetched again.

Usage: __self__pins__trees_present <file>
FUN
__self__pins__trees_present() {
  __self__pins__trees_present__dirs="$(self__pins__trees "$1")"
  args__call_with_lines __self__pins__dirs_present "$__self__pins__trees_present__dirs"
}

: <<'FUN'
Succeeds when every directory <dir...> exists, and fails at the first one
that does not.

args:
  $@  The directories
FUN
__self__pins__dirs_present() {
  for __self__pins__dirs_present__dir in "$@"; do
    [ -d "$__self__pins__dirs_present__dir" ] || return 1
  done
}

: <<'FUN'
Fetches every tree the lock <lock> names into the cache of <root>, mounts
the ones a dependency pins, removes the trees of each named dependency at
the commits the lock does not name, and writes the pins file <file>
whole, beside the standing one and moved into place.

Usage: __self__pins__write <root> <lock> <file>
FUN
__self__pins__write() {
  __self__pins__write__root="$1"
  __self__pins__write__lock="$2"
  __self__pins__write__file="$3"
  __self__pins__write__fresh="$__self__pins__write__file.$$"
  self__pins__forget
  mkdir -p "$(dirname "$__self__pins__write__file")"
  printf '# Generated by shellops from %s: where each git dependency'"'"'s tree is. Sourced by .envrc, which sets %s to the directory this file is in.\n' "$__self__pins__LOCK" "$__self__pins__TREES_REFERENCE" > "$__self__pins__write__fresh"

  __self__pins__write__entries="$(self__pins__entries "$__self__pins__write__lock")"
  if ! args__call_with_lines \
    __self__pins__pin_each \
    "$__self__pins__write__entries" \
    "$__self__pins__write__root" \
    "$__self__pins__write__fresh"; then
    rm -f "$__self__pins__write__fresh"
    return 1
  fi
  __self__pins__prune_each "$__self__pins__write__root"
  mv "$__self__pins__write__fresh" "$__self__pins__write__file"
}

: <<'FUN'
Removes, under the cache of <root>, the trees of every dependency pinned
in this run at the commits the run did not pin, so a pin that moved
leaves no tree behind and a dependency pinned at two commits keeps both.

Usage: __self__pins__prune_each <root>
FUN
__self__pins__prune_each() {
  __self__pins__prune_each__cache="$(self__pins__cache "$1")"
  __self__pins__prune_each__done=""
  for __self__pins__prune_each__word in $__self__pins__COMMITS; do
    __self__pins__prune_each__name="${__self__pins__prune_each__word%%=*}"
    case " $__self__pins__prune_each__done " in
      *" $__self__pins__prune_each__name "*) continue ;;
    esac
    __self__pins__prune_each__done="$__self__pins__prune_each__done $__self__pins__prune_each__name"
    # shellcheck disable=SC2046  # one commit per word, on purpose
    self__cache__prune "$__self__pins__prune_each__cache" "$__self__pins__prune_each__name" $(__self__pins__commit_of "$__self__pins__prune_each__name")
  done
}

: <<'FUN'
Pins each entry <entry...> under the cache of <root> and appends the line
it prints to <file>. Fails at the first entry whose tree cannot be
fetched.

args:
  $1  The repository's root
  $2  The file the lines are appended to
  $@  The entries, after those two, as self__pins__entries prints them
FUN
__self__pins__pin_each() {
  __self__pins__pin_each__root="$1"
  __self__pins__pin_each__file="$2"
  shift 2
  for __self__pins__pin_each__entry in "$@"; do
    args__call_with_fields __self__pins__pin "$__self__pins__pin_each__entry" '|' "$__self__pins__pin_each__root" >> "$__self__pins__pin_each__file" || return 1
  done
}

: <<'FUN'
Makes the tree of the dependency <name> at <commit> present under the
cache of <root>, mounts it at <mount> inside the tree of <via> when the
entry has a parent, and prints the line the pins file carries for it: the
export that names it, or a mounted line when the entry is shadowed
(__self__pins__shadowed). Fails, saying which, when the tree is absent and
cannot be fetched. The fields are one lock entry as self__pins__entries
prints it, and the ones it lacks are empty.

args:
  $1  The repository's root
  $2  The dependency's name
  $3  The commit it is pinned at
  $4  The repository it is fetched from, when declared
  $5  The parent it is reached through, when it has one
  $6  The path it is mounted at inside the parent, when it has one
FUN
__self__pins__pin() {
  __self__pins__pin__root="$1"
  __self__pins__pin__name="${2:-}"
  __self__pins__pin__commit="${3:-}"
  __self__pins__pin__repository="${4:-}"
  __self__pins__pin__via="${5:-}"
  __self__pins__pin__mount="${6:-}"
  __self__pins__pin__shadowed="$(__self__pins__shadowed "$__self__pins__pin__name" "$__self__pins__pin__via")"

  __self__pins__make_present \
    "$__self__pins__pin__root" \
    "$__self__pins__pin__name" \
    "$__self__pins__pin__commit" \
    "$__self__pins__pin__repository" \
    "$__self__pins__pin__via" \
    || return 1
  __self__pins__pin__recorded="$(self__cache__dir "$__self__pins__TREES_REFERENCE" "$__self__pins__pin__name" "$__self__pins__pin__commit")"
  self__pins__remember "$__self__pins__pin__name" "$__self__pins__pin__commit" "$__self__pins__pin__repository" "$__self__pins__pin__via"

  if [ -n "$__self__pins__pin__via" ] && [ -n "$__self__pins__pin__mount" ]; then
    __self__pins__pin__parent_commit="$(__self__pins__commit_of "$__self__pins__pin__via")"
    self__cache__mount "$(self__pins__cache "$__self__pins__pin__root")" "$__self__pins__pin__via" "$__self__pins__pin__parent_commit" "$__self__pins__pin__mount" "$__self__pins__pin__name" "$__self__pins__pin__commit"
  fi

  __self__pins__line "$__self__pins__pin__name" "$__self__pins__pin__recorded" "$__self__pins__pin__shadowed"
}

: <<'FUN'
Makes the tree of the dependency <name> at <commit> present under the
cache of <root>. Resolves the repository the lock entry names, with
<repository> and <via>, only when the tree is absent, so a root that has
the tree needs no origin. Fails, saying which, when the tree is absent and
its repository cannot be resolved or the tree cannot be fetched.

Usage: __self__pins__make_present <root> <name> <commit> <repository> <via>
FUN
__self__pins__make_present() {
  __self__pins__make_present__cache="$(self__pins__cache "$1")"
  if [ "$(self__cache__present "$__self__pins__make_present__cache" "$2" "$3")" = true ]; then  # structs-lint: allow -- plain shell, loaded before structs
    return 0
  fi
  __self__pins__make_present__url="$(self__pins__url "$1" "$2" "$4" "$5")" || return 1
  self__cache__ensure "$__self__pins__make_present__cache" "$2" "$__self__pins__make_present__url" "$3"
}

: <<'FUN'
Prints true when the entry for the dependency <name>, reached through
<via>, exports no variable: an entry under the same name has been pinned
before it in this run, and that entry's variable stands. The git channel
is pinned first (self__pins__entries), so a tool the repository pins
itself wins over the tree a dependency pins. Prints false for an entry
with no parent, and for the first entry under a name.

Usage: __self__pins__shadowed <name> <via>
FUN
__self__pins__shadowed() {
  if [ -n "$2" ] && [ -n "$(__self__pins__commit_of "$1")" ]; then  # structs-lint: allow -- plain shell, loaded before structs
    printf 'true\n'
  else
    printf 'false\n'
  fi
}

: <<'FUN'
Prints the line the pins file carries for the tree of the dependency
<name>, recorded as <recorded>: the export that names it, or, when
<shadowed> is true, a mounted line that lists the tree under no variable,
which self__pins__trees reads like an export.

  __self__pins__line shell-logs '$__self__pins__TREES/shell-logs/7f3d...' false  ->  export SHELL_LOGS_DIR="$__self__pins__TREES/shell-logs/7f3d..."
  __self__pins__line shell-logs '$__self__pins__TREES/shell-logs/7f3d...' true   ->  # mounted: $__self__pins__TREES/shell-logs/7f3d...

Usage: __self__pins__line <name> <recorded> <shadowed>
FUN
__self__pins__line() {
  if [ "$3" = true ]; then  # structs-lint: allow -- plain shell, loaded before structs
    printf '# mounted: %s\n' "$2"
  else
    printf 'export %s="%s"\n' "$(__self__pins__variable "$1")" "$2"
  fi
}

: <<'FUN'
Prints the name of the variable that names the dependency <name>'s tree:
the name in upper case, with each dash a low line, and _DIR after it.

  __self__pins__variable shell-logs   ->  SHELL_LOGS_DIR

Usage: __self__pins__variable <name>
FUN
__self__pins__variable() {
  printf '%s_DIR\n' "$1" | tr 'a-z-' 'A-Z_'
}

: <<'PUB_FUN'
Prints the repository the dependency <name> is fetched from: <NAME>_URL
from the environment when set; else, for a dependency reached through the
parent <via>, the repository beside the parent's, whatever <repository>
says; else <repository> as it is when it names a repository on its own,
or resolved against the origin of <root> when it is relative; else, with
no <repository>, the repository beside the origin of <root>. The parent
must have been remembered with self__pins__remember. Fails, saying so,
when the repository is beside the origin of <root> and <root> has none.

  self__pins__url /p strata '' ''                                        ->  https://forge/ksoft/strata.git
  self__pins__url /p shell-logs https://elsewhere/shell-logs.git strata  ->  https://forge/ksoft/shell-logs.git
  self__pins__url /p shell-docs https://forge/x/shell-docs.git ''        ->  https://forge/x/shell-docs.git

Usage: self__pins__url <root> <name> <repository> <via>
PUB_FUN
self__pins__url() {
  __self__pins__url__override="$(__self__pins__override "$2")"
  if [ -n "$__self__pins__url__override" ]; then  # structs-lint: allow -- plain shell, loaded before structs
    println "$__self__pins__url__override"
    return 0
  fi
  if [ -n "$4" ]; then
    __self__pins__url__parent="$(__self__pins__url_of "$1" "$4")" || return 1
    git__trees__url "../$2.git" "$__self__pins__url__parent"
    return 0
  fi
  if [ -n "${3:-}" ]; then
    __self__pins__declared_url "$1" "$3"
    return
  fi
  __self__pins__url__base="$(git__trees__origin "$1")" || return 1
  git__trees__url "../$2.git" "$__self__pins__url__base"
}

: <<'FUN'
Prints the repository a direct entry of <root> declares as <repository>:
as it is when it names a repository on its own, and resolved against the
origin of <root> when it is relative. Fails when a relative one meets a
root with no origin.

Usage: __self__pins__declared_url <root> <repository>
FUN
__self__pins__declared_url() {
  if [ "$(git__trees__url_is_absolute "$2")" = true ]; then  # structs-lint: allow -- plain shell, loaded before structs
    println "$2"
    return 0
  fi
  __self__pins__declared_url__base="$(git__trees__origin "$1")" || return 1
  git__trees__url "$2" "$__self__pins__declared_url__base"
}

: <<'FUN'
Prints the value of <NAME>_URL in the environment for the dependency
<name>, or nothing when it is unset.

Usage: __self__pins__override <name>
FUN
__self__pins__override() {
  __self__pins__override__variable="$(__self__pins__variable "$1")"
  __self__pins__override__variable="${__self__pins__override__variable%_DIR}_URL"
  eval "printf '%s\n' \"\${$__self__pins__override__variable:-}\""
}

: <<'PUB_FUN'
Records that the dependency <name> is pinned at <commit>, and that its
lock entry names <repository> and is reached through <via>, so a
dependency reached through it mounts against its tree and resolves its
own repository beside it. <repository> and <via> are empty when the entry
names none.

Usage: self__pins__remember <name> <commit> <repository> <via>
PUB_FUN
self__pins__remember() {
  __self__pins__COMMITS="$__self__pins__COMMITS $1=$2"
  __self__pins__SOURCES="$__self__pins__SOURCES $1=${3:-}|${4:-}"
}

: <<'PUB_FUN'
Forgets every dependency remembered in this run, before a new run.

Usage: self__pins__forget
PUB_FUN
self__pins__forget() {
  __self__pins__COMMITS=""
  __self__pins__SOURCES=""
}

: <<'FUN'
Prints the repository of the dependency <name> remembered in this run,
resolved for <root> as self__pins__url resolves the entry it was
remembered with. Fails when that repository cannot be resolved.

Usage: __self__pins__url_of <root> <name>
FUN
__self__pins__url_of() {
  __self__pins__url_of__source="$(__self__pins__lookup "$__self__pins__SOURCES" "$2")"
  self__pins__url "$1" "$2" "${__self__pins__url_of__source%%|*}" "${__self__pins__url_of__source#*|}"
}

: <<'FUN'
Prints the commit the dependency <name> was pinned at in this run, and
nothing when it has not been.

Usage: __self__pins__commit_of <name>
FUN
__self__pins__commit_of() {
  __self__pins__lookup "$__self__pins__COMMITS" "$1"
}

: <<'FUN'
Prints the value of <name> in the "<name>=<value>" words of <table>, and
nothing when the table has no such word.

Usage: __self__pins__lookup <table> <name>
FUN
__self__pins__lookup() {
  for __self__pins__lookup__word in $1; do
    case "$__self__pins__lookup__word" in
      "$2="*) printf '%s\n' "${__self__pins__lookup__word#"$2="}" ;;
    esac
  done
}

: <<'PUB_FUN'
Prints the trees the pins file <file> names, one per line, in the order it
names them: the ones its variables name and the ones its mounted lines
list alike. Each is under the directory <file> is in, wherever the file
was when it was written.

  self__pins__trees /p/.ops/cache/pins.sh  ->  /p/.ops/cache/strata/73e6...
                                               /p/.ops/cache/shell-goldens/5cbd...
                                               /p/.ops/cache/shell-logs/7f3d...

Usage: self__pins__trees <file>
PUB_FUN
self__pins__trees() {
  __self__pins__trees__cache="${1%/*}"
  __self__pins__recorded_trees "$1" | while IFS= read -r __self__pins__trees__recorded; do
    __self__pins__located "$__self__pins__trees__cache" "$__self__pins__trees__recorded"
    println "$__self__pins__located__dir"
  done
}

: <<'FUN'
Prints the trees the pins file <file> names, one per line, in the order it
names them and as it records them: the ones its variables name and the
ones its mounted lines list alike.

  __self__pins__recorded_trees /p/.ops/cache/pins.sh  ->  $__self__pins__TREES/strata/73e6...
                                                          $__self__pins__TREES/shell-goldens/5cbd...

Usage: __self__pins__recorded_trees <file>
FUN
__self__pins__recorded_trees() {
  sed -n \
    -e 's/^export [A-Z_]*_DIR="\(.*\)"$/\1/p' \
    -e 's/^# mounted: \(.*\)$/\1/p' \
    "$1"
}

: <<'FUN'
Sets __self__pins__located__dir to the tree that a pins file in the
directory <cache> records as <recorded>: under <cache> when the record
starts with the reference to that directory, and <recorded> as it is when
it is an absolute path. Sets a variable rather than printing, so asking
forks nothing.

  __self__pins__located /p/.ops/cache '$__self__pins__TREES/strata/73e6...'  ->  __self__pins__located__dir=/p/.ops/cache/strata/73e6...
  __self__pins__located /p/.ops/cache /q/.ops/cache/strata/73e6...          ->  __self__pins__located__dir=/q/.ops/cache/strata/73e6...

Usage: __self__pins__located <cache> <recorded>
FUN
__self__pins__located() {
  __self__pins__located__dir="$2"
  __self__pins__located__under="${2#"$__self__pins__TREES_REFERENCE"/}"
  if [ "$__self__pins__located__under" != "$2" ]; then
    __self__pins__located__dir="$1/$__self__pins__located__under"
  fi
}

: <<'PUB_FUN'
Prints the path of the command <name> among the trees the pins name: the
executable cli/<name> of the first tree that carries one, the trees PROJ's
lock names before shellops' own, and nothing when none carries one. Reads
the pins files as self__pins__ensure left them.

  self__pins__command lint  ->  /p/.ops/cache/shell-lint/6bb8.../cli/lint

Usage: self__pins__command <name>
PUB_FUN
self__pins__command() {
  __self__pins__all_trees | __self__pins__first_carrying "$1"
}

: <<'FUN'
Prints the executable cli/<name> of the first tree read from stdin, one
tree per line, that carries one, and nothing when none does. Reads every
line, so that the writer is never cut off under pipefail.

Usage: ... | __self__pins__first_carrying <name>
FUN
__self__pins__first_carrying() {
  __self__pins__first_carrying__path=""
  while IFS= read -r __self__pins__first_carrying__dir; do
    if [ -z "$__self__pins__first_carrying__path" ] && [ -x "$__self__pins__first_carrying__dir/cli/$1" ]; then  # structs-lint: allow -- plain shell, loaded before structs
      __self__pins__first_carrying__path="$__self__pins__first_carrying__dir/cli/$1"
    fi
  done
  if [ -n "$__self__pins__first_carrying__path" ]; then  # structs-lint: allow -- plain shell, loaded before structs
    println "$__self__pins__first_carrying__path"
  fi
}

: <<'PUB_FUN'
Prints the commands the trees the pins name carry, one per line as
"<name> <dependency>": each name once, from the first tree that carries an
executable cli/<name>, the trees PROJ's lock names before shellops' own.
The dependency is the one the tree is cached under.

  self__pins__commands  ->  lint shell-lint
                            docs shell-docs

Usage: self__pins__commands
PUB_FUN
self__pins__commands() {
  __self__pins__all_trees | while IFS= read -r __self__pins__commands__dir; do
    __self__pins__commands_of "$__self__pins__commands__dir"
  done | __self__pins__first_of_each
}

: <<'FUN'
Prints the pins files this shell runs on, PROJ's before shellops' own, the
ones that exist and each once. PROJ's exists when its lock names a git
dependency, since self__pins__ensure writes it then.

Usage: __self__pins__files
FUN
__self__pins__files() {
  __self__pins__files__proj="${PROJ:-$SHELLOPS_DIR}/$__self__pins__FILE"
  __self__pins__files__own="$SHELLOPS_DIR/$__self__pins__FILE"
  if [ -f "$__self__pins__files__proj" ]; then
    println "$__self__pins__files__proj"
  fi
  if [ "$__self__pins__files__own" != "$__self__pins__files__proj" ] && [ -f "$__self__pins__files__own" ]; then
    println "$__self__pins__files__own"
  fi
}

: <<'FUN'
Prints every tree the pins files this shell runs on name, one per line,
PROJ's before shellops' own.

Usage: __self__pins__all_trees
FUN
__self__pins__all_trees() {
  __self__pins__files | while IFS= read -r __self__pins__all_trees__file; do
    self__pins__trees "$__self__pins__all_trees__file"
  done
}

: <<'FUN'
Prints the commands the tree <dir> carries, one per line as
"<name> <dependency>": its executables under cli/, and nothing when it has
none. The dependency is the name of the tree's parent directory, since the
cache keys a tree by dependency and then by commit (self__cache__dir).

  __self__pins__commands_of /p/.ops/cache/shell-lint/6bb8...  ->  lint shell-lint

Usage: __self__pins__commands_of <dir>
FUN
__self__pins__commands_of() {
  __self__pins__commands_of__dependency="${1%/*}"
  __self__pins__commands_of__dependency="${__self__pins__commands_of__dependency##*/}"
  for __self__pins__commands_of__path in "$1"/cli/*; do
    if [ -x "$__self__pins__commands_of__path" ]; then
      printf '%s %s\n' "${__self__pins__commands_of__path##*/}" "$__self__pins__commands_of__dependency"
    fi
  done
}

: <<'FUN'
Prints the lines read from stdin whose first word has not been read before,
in their order, so that a command two trees carry is listed once, from the
tree the pins name first.

Usage: ... | __self__pins__first_of_each
FUN
__self__pins__first_of_each() {
  __self__pins__first_of_each__seen=" "
  while IFS= read -r __self__pins__first_of_each__line; do
    __self__pins__first_of_each__name="${__self__pins__first_of_each__line%% *}"
    if [ "${__self__pins__first_of_each__seen#*" $__self__pins__first_of_each__name "}" = "$__self__pins__first_of_each__seen" ]; then
      println "$__self__pins__first_of_each__line"
      __self__pins__first_of_each__seen="$__self__pins__first_of_each__seen$__self__pins__first_of_each__name "
    fi
  done
}
