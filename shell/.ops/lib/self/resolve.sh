#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/self/config.sh" \
  "$SHELLOPS_DIR/lib/self/dependencies/api.sh" \
  "$SHELLOPS_DIR/lib/self/lock/api.sh" \
  "$SHELLOPS_DIR/lib/self/cache.sh" \
  "$SHELLOPS_DIR/lib/self/pins.sh" \
  "$SHELLOPS_DIR/lib/self/shellops.sh" \
  "$SHELLOPS_DIR/lib/args/lines.sh"

: <<'MODULE'
The resolver over a repository's run-time git dependencies (ADR 000050):
what ops install derives the lock's dependencies.imports from.

A run-time dependency is an entry of imports.yaml. It names the commit it
is pinned at, and may name the repository it is fetched from, as
.gitmodules writes one, relative to the repository that declares it. A
dependency reached through another is fetched from beside its parent
(lib/self/pins.sh), whatever the parent's own declaration names, so the
lock records no repository for it. The
resolver fetches each tree and walks it: a dependency whose lock records
imports contributes them, reached through it; one whose lock records
none, or that has no lock, has not declared its run-time dependencies
yet and contributes the submodules it pins, each recorded with the path
it is mounted at, except a vendored shellops, which is this resolver. The git channel of tools.yaml is not the
resolver's: the toolchain fetches a dev-time tree when it installs it,
and the lock records it under dependencies.tools.git like every channel.

One commit of a repository per process: a repository reached at two
commits is refused, naming both paths, until repositories certify their
features and the newest certified commit can be chosen instead.

An entry on its way through the resolver is one struct:

  {name, commit, repository, via, mount, path}

where path is the chain it was reached by, "strata > shell-logs", for a
refusal to name, and repository is a direct entry's own. The lock keeps
the entry without its name and path.

  self__resolve__imports /repo
    ->  {"strata":{"commit":"73e6..."},
         "shell-logs":{"commit":"7f3d...","via":"strata","mount":"shell/.logs"}}
MODULE

# CONST: The entries queued for the next round, as a struct array.
__self__resolve__QUEUE=""

# CONST: The dependencies resolved so far, the map the lock records.
__self__resolve__RESOLVED=""

# CONST: The path each resolved dependency was reached by, for a refusal to name: {<name>: "strata > shell-logs"}.
__self__resolve__PATHS=""

# CONST: The declaration whose entries are being queued, as a struct.
__self__resolve__DECLARED=""

# CONST: The root of the repository being resolved.
__self__resolve__ROOT=""

# CONST: The entry whose pins are being queued, while its lock or its gitlinks are walked.
__self__resolve__PARENT=""

: <<'PUB_FUN'
Prints the run-time git dependencies of the repository <root> as the lock
records them under dependencies.imports, fetching every tree into the
repository's cache on the way. Fails, saying which, when a tree cannot be
fetched or a repository is reached at two commits.

args:
  $1  The repository's root; $PROJ when omitted
PUB_FUN
self__resolve__imports() {
  __self__resolve__ROOT="${1:-$PROJ}"
  @arr __self__resolve__QUEUE
  @obj __self__resolve__RESOLVED
  @obj __self__resolve__PATHS
  self__pins__forget

  __self__resolve__queue_declared || return 1

  while @len __self__resolve__imports__len_1 "$__self__resolve__QUEUE"; [ "$__self__resolve__imports__len_1" -gt 0 ]; do
    __self__resolve__imports__round="$__self__resolve__QUEUE"
    @arr __self__resolve__QUEUE
    @foreach __self__resolve__take "$__self__resolve__imports__round" || return 1
  done

  println "$__self__resolve__RESOLVED"
}

: <<'FUN'
Queues every entry of the root's imports.yaml, pinned at the commit it
names. A repository without an imports.yaml queues nothing.
FUN
__self__resolve__queue_declared() {
  if ! @is_true "$(self__config__present imports "$__self__resolve__ROOT")"; then
    return 0
  fi
  __self__resolve__DECLARED="$(self__config__load imports "$__self__resolve__ROOT")" || return 1
  @keys __self__resolve__queue_declared__keys_2 "$__self__resolve__DECLARED"
  @foreach __self__resolve__queue_one "$__self__resolve__queue_declared__keys_2"
}

: <<'FUN'
@foreach callback: queues the declared entry of the wrapped name <name>,
pinned at the commit it names and fetched from the repository it names,
reached directly.

args:
  $1  The entry's name, wrapped
FUN
__self__resolve__queue_one() {
  @unwrap __self__resolve__queue_one__name "$1"
  @get __self__resolve__queue_one__declared "$__self__resolve__DECLARED" ".\"$__self__resolve__queue_one__name\""
  @get __self__resolve__queue_one__get_3 "$__self__resolve__queue_one__declared" '.commit' ''
  @get __self__resolve__queue_one__get_4 "$__self__resolve__queue_one__declared" '.repository' ''
  @obj __self__resolve__queue_one__obj_5 \
    '.name' "$__self__resolve__queue_one__name" \
    '.commit' "$__self__resolve__queue_one__get_3" \
    '.repository' "$__self__resolve__queue_one__get_4" \
    '.via' '' \
    '.mount' '' \
    '.path' "$__self__resolve__queue_one__name"
  __self__resolve__push "$__self__resolve__queue_one__obj_5"
}

: <<'FUN'
Appends the entry <entry> to the queue for the next round.

args:
  $1  The entry, as a struct
FUN
__self__resolve__push() {
  @push __self__resolve__QUEUE "$__self__resolve__QUEUE" "$1"
}

: <<'FUN'
@foreach callback: resolves one queued entry. Refuses a commit that
disagrees with one already resolved for the name, fetches the tree,
records the entry, and queues what the dependency pins in turn.

args:
  $1  The entry, as a struct
FUN
__self__resolve__take() {
  @get __self__resolve__take__name "$1" '.name'
  @get __self__resolve__take__commit "$1" '.commit' ''
  @get __self__resolve__take__repository "$1" '.repository' ''
  @get __self__resolve__take__via "$1" '.via' ''
  @get __self__resolve__take__path "$1" '.path'

  if ! @defined "$__self__resolve__take__commit"; then
    error "$__self__resolve__take__path names no commit; a dependency is pinned at a commit (ADR 000050)"
    return 1
  fi

  if @get __self__resolve__take__get_6 "$__self__resolve__RESOLVED" ".\"$__self__resolve__take__name\".commit" ''; @defined "$__self__resolve__take__get_6"; then
    __self__resolve__agree "$1"
    return
  fi

  __self__resolve__take__url="$(self__pins__url "$__self__resolve__ROOT" "$__self__resolve__take__name" "$__self__resolve__take__repository" "$__self__resolve__take__via")" || return 1
  self__cache__ensure "$(self__pins__cache "$__self__resolve__ROOT")" "$__self__resolve__take__name" "$__self__resolve__take__url" "$__self__resolve__take__commit" || return 1
  self__pins__remember "$__self__resolve__take__name" "$__self__resolve__take__commit" "$__self__resolve__take__repository" "$__self__resolve__take__via"

  __self__resolve__record "$1"
  __self__resolve__queue_pins_of "$1"
}

: <<'FUN'
Succeeds quietly when the entry <entry> pins the name at the commit
already resolved for it, and fails naming both paths otherwise.

args:
  $1  The entry, as a struct
FUN
__self__resolve__agree() {
  @get __self__resolve__agree__name "$1" '.name'
  @get __self__resolve__agree__commit "$1" '.commit'
  @get __self__resolve__agree__path "$1" '.path'
  @get __self__resolve__agree__known "$__self__resolve__RESOLVED" ".\"$__self__resolve__agree__name\".commit"
  if [ "$__self__resolve__agree__known" = "$__self__resolve__agree__commit" ]; then
    return 0
  fi
  @get __self__resolve__agree__first "$__self__resolve__PATHS" ".\"$__self__resolve__agree__name\"" ''
  error "$__self__resolve__agree__name is pinned at two commits: $__self__resolve__agree__known by $__self__resolve__agree__first and $__self__resolve__agree__commit by $__self__resolve__agree__path; one commit of a repository loads per process (ADR 000050), so align the pins"
  return 1
}

: <<'FUN'
Records the entry <entry> on the map the lock takes: its commit always,
and its repository, the dependency it was reached through and its
mount path when it has them. The path it was reached by is kept aside for
a refusal to name.

args:
  $1  The entry, as a struct
FUN
__self__resolve__record() {
  @get __self__resolve__record__name "$1" '.name'
  @get __self__resolve__record__repository "$1" '.repository' ''
  @get __self__resolve__record__via "$1" '.via' ''
  @get __self__resolve__record__mount "$1" '.mount' ''
  @get __self__resolve__record__path "$1" '.path'
  @get __self__resolve__record__get_7 "$1" '.commit'
  @obj __self__resolve__record__entry '.commit' "$__self__resolve__record__get_7"
  if @defined "$__self__resolve__record__repository"; then
    @set __self__resolve__record__entry "$__self__resolve__record__entry" '.repository' "$__self__resolve__record__repository"
  fi
  if @defined "$__self__resolve__record__via"; then
    @set __self__resolve__record__entry "$__self__resolve__record__entry" '.via' "$__self__resolve__record__via"
  fi
  if @defined "$__self__resolve__record__mount"; then
    @set __self__resolve__record__entry "$__self__resolve__record__entry" '.mount' "$__self__resolve__record__mount"
  fi
  @set __self__resolve__RESOLVED "$__self__resolve__RESOLVED" ".\"$__self__resolve__record__name\"" "$__self__resolve__record__entry"
  @set __self__resolve__PATHS "$__self__resolve__PATHS" ".\"$__self__resolve__record__name\"" "$__self__resolve__record__path"
}

: <<'FUN'
Queues what the dependency of the entry <entry> pins in turn: the imports
its lock records when it records any, and otherwise the submodules it
pins, except a vendored shellops. A lock that records no imports is one
the repository keeps for its tools before it declares its run-time
dependencies, so its submodules still stand for them.

args:
  $1  The entry, as a struct
FUN
__self__resolve__queue_pins_of() {
  __self__resolve__PARENT="$1"
  @get __self__resolve__queue_pins_of__get_8 "$1" '.name'
  @get __self__resolve__queue_pins_of__get_9 "$1" '.commit'
  __self__resolve__queue_pins_of__tree="$(self__cache__dir "$(self__pins__cache "$__self__resolve__ROOT")" "$__self__resolve__queue_pins_of__get_8" "$__self__resolve__queue_pins_of__get_9")"
  __self__resolve__queue_pins_of__imports="$(__self__resolve__recorded_imports "$__self__resolve__queue_pins_of__tree")"
  if @len __self__resolve__queue_pins_of__len_10 "$__self__resolve__queue_pins_of__imports"; [ "$__self__resolve__queue_pins_of__len_10" -gt 0 ]; then
    __self__resolve__queue_lock_of "$__self__resolve__queue_pins_of__imports"
  else
    __self__resolve__queue_gitlinks_of "$__self__resolve__queue_pins_of__tree"
  fi
}

: <<'FUN'
Prints the imports the lock of the tree <tree> records, and the empty map
when the tree has no lock or its lock records none.

args:
  $1  The tree
FUN
__self__resolve__recorded_imports() {
  if @is_true "$(self__lock__present "$1")"; then
    self__dependencies__imports "$1"
  else
    @obj __self__resolve__recorded_imports__out
    println "$__self__resolve__recorded_imports__out"
  fi
}

: <<'FUN'
Queues the imports <imports> the lock of the parent being walked records,
each reached through it.

args:
  $1  The imports, as the lock records them
FUN
__self__resolve__queue_lock_of() {
  __self__resolve__queue_lock_of__imports="$1"
  @keys __self__resolve__queue_lock_of__keys_11 "$__self__resolve__queue_lock_of__imports"
  @foreach __self__resolve__queue_lock_entry "$__self__resolve__queue_lock_of__keys_11"
}

: <<'FUN'
@foreach callback: queues the import of the wrapped name <name> of the
parent being walked.

args:
  $1  The entry's name, wrapped
FUN
__self__resolve__queue_lock_entry() {
  @unwrap __self__resolve__queue_lock_entry__name "$1"
  @get __self__resolve__queue_lock_entry__entry "$__self__resolve__queue_lock_of__imports" ".\"$__self__resolve__queue_lock_entry__name\""
  @get __self__resolve__queue_lock_entry__commit "$__self__resolve__queue_lock_entry__entry" '.commit' ''
  @get __self__resolve__queue_lock_entry__mount "$__self__resolve__queue_lock_entry__entry" '.mount' ''
  __self__resolve__push "$(__self__resolve__child \
    "$__self__resolve__queue_lock_entry__name" \
    "$__self__resolve__queue_lock_entry__commit" \
    "$__self__resolve__queue_lock_entry__mount"
  )"
}

: <<'FUN'
Queues the submodules the parent being walked pins, read from the gitlinks
beside its tree <tree> and named by its .gitmodules, each reached through
it and mounted at its path. A vendored shellops is left out: it is this
resolver, not a dependency.

args:
  $1  The parent's tree
FUN
__self__resolve__queue_gitlinks_of() {
  __self__resolve__queue_gitlinks_of__cache="$(self__pins__cache "$__self__resolve__ROOT")"
  @get __self__resolve__queue_gitlinks_of__name "$__self__resolve__PARENT" '.name'
  @get __self__resolve__queue_gitlinks_of__commit "$__self__resolve__PARENT" '.commit'
  __self__resolve__queue_gitlinks_of__gitlinks="$(self__cache__gitlinks \
    "$__self__resolve__queue_gitlinks_of__cache" \
    "$__self__resolve__queue_gitlinks_of__name" \
    "$__self__resolve__queue_gitlinks_of__commit"
  )"
  args__call_with_lines __self__resolve__queue_gitlinks "$__self__resolve__queue_gitlinks_of__gitlinks" "$1"
}

: <<'FUN'
Queues each of the gitlinks <gitlink...> of the parent being walked, whose
tree stands at <tree>.

args:
  $1  The parent's tree
  $@  The gitlinks, after it, each "<path> <commit>"
FUN
__self__resolve__queue_gitlinks() {
  __self__resolve__queue_gitlinks__tree="$1"
  shift
  for __self__resolve__queue_gitlinks__gitlink in "$@"; do
    __self__resolve__queue_gitlink "$__self__resolve__queue_gitlinks__tree" "$__self__resolve__queue_gitlinks__gitlink"
  done
}

: <<'FUN'
Queues one submodule of the parent being walked, whose tree stands at
<tree>: the gitlink "<path> <commit>", named after the repository its
.gitmodules entry points at, unless that is a vendored shellops.

args:
  $1  The parent's tree
  $2  The gitlink, "<path> <commit>"
FUN
__self__resolve__queue_gitlink() {
  __self__resolve__queue_gitlink__path="${2%% *}"
  __self__resolve__queue_gitlink__commit="${2#* }"
  __self__resolve__queue_gitlink__url="$(git__submodule_url "$1" "$__self__resolve__queue_gitlink__path")"
  if ! @defined "$__self__resolve__queue_gitlink__url"; then
    return 0
  fi
  __self__resolve__queue_gitlink__name="${__self__resolve__queue_gitlink__url##*/}"
  __self__resolve__queue_gitlink__name="${__self__resolve__queue_gitlink__name%.git}"
  if @is_true "$(self__shellops__is_vendored "$1" "$__self__resolve__queue_gitlink__path")"; then
    return 0
  fi
  __self__resolve__push "$(__self__resolve__child \
    "$__self__resolve__queue_gitlink__name" \
    "$__self__resolve__queue_gitlink__commit" \
    "$__self__resolve__queue_gitlink__path"
  )"
}

: <<'FUN'
Prints the entry for a dependency the parent being walked pins:
<name> at <commit>, mounted at <mount> when the parent pins it as a
submodule, reached through the parent. It names no repository: a
dependency reached through another is fetched from beside its parent.

  __self__resolve__child shell-logs 7f3d... shell/.logs
    ->  {"name":"shell-logs","commit":"7f3d...","repository":"","via":"strata","mount":"shell/.logs","path":"strata > shell-logs"}

args:
  $1  The name
  $2  The commit
  $3  The mount path, or the empty string
FUN
__self__resolve__child() {
  @get __self__resolve__child__parent "$__self__resolve__PARENT" '.name'
  @get __self__resolve__child__path "$__self__resolve__PARENT" '.path'
  @obj __self__resolve__child__out \
    '.name' "$1" \
    '.commit' "$2" \
    '.repository' "" \
    '.via' "$__self__resolve__child__parent" \
    '.mount' "$3" \
    '.path' "$__self__resolve__child__path > $1"
  println "$__self__resolve__child__out"
}
