#!/bin/sh

import "$SHELLOPS_DIR/lib/git/trees/api.sh"

: <<'MODULE'
The cache of git trees a repository runs on: each tree fetched at a commit
as plain files, and never tracked (ADR 000048, ADR 000050). A tree is one
entry under <cache>/<name>/<commit>/, holding that commit's files and no
repository. Beside the entry, <commit>.gitlinks lists the submodules the
commit pins, one "<path> <commit>" per line, so a caller can walk a
dependency that pins its own dependencies that way. A tree a dependency
pins as a submodule is mounted inside the dependency's tree by a link, so
a dependency that reads it by a path of its own finds it there.

The module is plain shell and calls no structs verb: a boot fills the
cache before the structs library loads. It takes the cache directory from
its caller, so it knows nothing of where a repository keeps its cache.

  self__cache__ensure /p/.ops/cache strata https://forge/ksoft/strata.git 73e6...
    ->  /p/.ops/cache/strata/73e6.../shell/silt/api.sh exists
  self__cache__dir /p/.ops/cache strata 73e6...
    ->  /p/.ops/cache/strata/73e6...
MODULE

: <<'PUB_FUN'
Sets __self__cache__entry__dir to where the cache <cache> keeps the tree
of the commit <commit> of the dependency <name>. Sets a variable rather
than printing, so asking forks nothing.

Usage: self__cache__entry <cache> <name> <commit>
PUB_FUN
self__cache__entry() {
  __self__cache__entry__dir="$1/$2/$3"
}

: <<'PUB_FUN'
Prints where the cache <cache> keeps the tree of the commit <commit> of
the dependency <name>, whether or not the tree is present.

  self__cache__dir /p/.ops/cache strata 73e6...   ->  /p/.ops/cache/strata/73e6...

Usage: self__cache__dir <cache> <name> <commit>
PUB_FUN
self__cache__dir() {
  self__cache__entry "$1" "$2" "$3"
  println "$__self__cache__entry__dir"
}

: <<'PUB_FUN'
Prints true when the tree of the commit <commit> of the dependency <name>
is present under the cache <cache>, false otherwise.

Usage: self__cache__present <cache> <name> <commit>
PUB_FUN
self__cache__present() {
  self__cache__entry "$1" "$2" "$3"
  if [ -d "$__self__cache__entry__dir" ]; then
    println true
  else
    println false
  fi
}

: <<'PUB_FUN'
Makes the tree of the commit <commit> of the dependency <name>, fetched
from <url>, present under the cache <cache>, and sets
__self__cache__entry__dir to it. Fetches the tree when it is absent, and
leaves the trees of other commits of <name> as they are: a lock may name
one dependency at two commits, and self__cache__prune removes the trees a
caller no longer names. Fails, naming the commit and the repository, when
the tree is absent and cannot be fetched.

Usage: self__cache__ensure <cache> <name> <url> <commit>
PUB_FUN
self__cache__ensure() {
  self__cache__entry "$1" "$2" "$4"
  if [ "$(self__cache__present "$1" "$2" "$4")" = true ]; then  # structs-lint: allow -- plain shell, loaded before structs
    return 0
  fi
  __self__cache__install "$2" "$3" "$4"
}

: <<'PUB_FUN'
Prints the submodules the commit <commit> of the dependency <name> pins,
one "<path> <commit>" per line, and nothing when it pins none or the tree
is absent from the cache <cache>.

  self__cache__gitlinks /p/.ops/cache strata 73e6...
    ->  shell/.logs 7f3dd9d59cd09d237c70e50bb68e795ebf56dc57
        shell/.ops 57bcedf07ccd40fcf477e9bbba59acb26a2c97d9

Usage: self__cache__gitlinks <cache> <name> <commit>
PUB_FUN
self__cache__gitlinks() {
  self__cache__entry "$1" "$2" "$3"
  if [ -f "$__self__cache__entry__dir.gitlinks" ]; then
    cat "$__self__cache__entry__dir.gitlinks"
  fi
}

: <<'PUB_FUN'
Links the tree of the commit <commit> of <name> into the tree of the
commit <parent_commit> of <parent> at the path <path>, both under the
cache <cache>, replacing whatever stands at that path. The link is
relative, so the cache can move whole.

  self__cache__mount /p/.ops/cache strata 73e6... shell/.logs shell-logs 7f3d...
    ->  /p/.ops/cache/strata/73e6.../shell/.logs -> ../../../shell-logs/7f3d...

Usage: self__cache__mount <cache> <parent> <parent_commit> <path> <name> <commit>
PUB_FUN
self__cache__mount() {
  self__cache__entry "$1" "$2" "$3"
  __self__cache__mount__at="$__self__cache__entry__dir/$4"
  __self__cache__mount__target="$(__self__cache__ups "$4")$5/$6"
  rm -rf "$__self__cache__mount__at"
  mkdir -p "$(dirname "$__self__cache__mount__at")"
  ln -s "$__self__cache__mount__target" "$__self__cache__mount__at"
}

: <<'PUB_FUN'
Removes every tree of the dependency <name> under the cache <cache>, and
its gitlinks, but the ones at the commits <commit...>, so the cache keeps
the trees a lock names and no more. A tree another shell is still
fetching, named with its pid, and its gitlinks are left to it.

  self__cache__prune /p/.ops/cache shell-goldens 0bed... 5cbd...
    ->  /p/.ops/cache/shell-goldens holds 0bed..., 5cbd... and their gitlinks

Usage: self__cache__prune <cache> <name> <commit...>
PUB_FUN
self__cache__prune() {
  __self__cache__prune__dir="$1/$2"
  shift 2
  for __self__cache__prune__entry in "$__self__cache__prune__dir"/*; do
    [ -e "$__self__cache__prune__entry" ] || continue
    __self__cache__prune__commit="$(__self__cache__commit_of_entry "${__self__cache__prune__entry##*/}")"
    if [ -z "$__self__cache__prune__commit" ]; then  # structs-lint: allow -- plain shell, loaded before structs
      continue
    fi
    if [ "$(__self__cache__kept "$__self__cache__prune__commit" "$@")" = true ]; then  # structs-lint: allow -- plain shell, loaded before structs
      continue
    fi
    rm -rf "$__self__cache__prune__entry"
  done
}

: <<'FUN'
Fetches the tree of the commit <commit> of <name> from <url> into the
entry self__cache__entry named, as plain files with the submodules it pins
listed beside it. Fails, saying why, when the fetch fails.

Usage: __self__cache__install <name> <url> <commit>
FUN
__self__cache__install() {
  __self__cache__install__fresh="$__self__cache__entry__dir.$$"

  if ! git__trees__fetch "$2" "$3" "$__self__cache__install__fresh"; then
    rm -rf "$__self__cache__install__fresh"
    error "$1 at $3 could not be fetched from $2"
    return 1
  fi

  git__trees__gitlinks "$__self__cache__install__fresh" > "$__self__cache__install__fresh.gitlinks"
  rm -rf "${__self__cache__install__fresh:?}/.git"
  __self__cache__publish "$__self__cache__install__fresh"
}

: <<'FUN'
Puts the fresh tree <fresh> and its gitlinks in place as the entry
self__cache__entry named. When an entry stands there already, another
shell fetched it first, and <fresh> is dropped.

Usage: __self__cache__publish <fresh>
FUN
__self__cache__publish() {
  if [ -d "$__self__cache__entry__dir" ]; then
    rm -rf "$1" "$1.gitlinks"
    return 0
  fi
  mv "$1.gitlinks" "$__self__cache__entry__dir.gitlinks"
  mv "$1" "$__self__cache__entry__dir"
}

: <<'FUN'
Prints the commit the cache entry <entry> belongs to: the entry's own
name for a tree, and the name before .gitlinks for a gitlinks file.
Prints nothing for a tree another shell is still fetching, named with its
pid, or for that tree's gitlinks.

  __self__cache__commit_of_entry 5cbd...           ->  5cbd...
  __self__cache__commit_of_entry 5cbd....gitlinks  ->  5cbd...
  __self__cache__commit_of_entry 5cbd....4242      ->  (nothing)

Usage: __self__cache__commit_of_entry <entry>
FUN
__self__cache__commit_of_entry() {
  case "$1" in
    *.*.gitlinks) ;;
    *.gitlinks) println "${1%.gitlinks}" ;;
    *.*) ;;
    *) println "$1" ;;
  esac
}

: <<'FUN'
Prints true when the commit <commit> is among <commit...>, false
otherwise.

Usage: __self__cache__kept <commit> <commit...>
FUN
__self__cache__kept() {
  __self__cache__kept__commit="$1"
  shift
  for __self__cache__kept__each in "$@"; do
    if [ "$__self__cache__kept__each" = "$__self__cache__kept__commit" ]; then
      println true
      return 0
    fi
  done
  println false
}

: <<'FUN'
Prints the "../" that climbs from the directory the path <path> names,
inside a tree's entry, up to the cache: one for each segment of the path,
and one more for the entry's own directory.

  __self__cache__ups shell/.logs   ->  ../../../

Usage: __self__cache__ups <path>
FUN
__self__cache__ups() {
  __self__cache__ups__rest="$1"
  __self__cache__ups__out="../../"
  while [ "${__self__cache__ups__rest#*/}" != "$__self__cache__ups__rest" ]; do
    __self__cache__ups__out="$__self__cache__ups__out../"
    __self__cache__ups__rest="${__self__cache__ups__rest#*/}"
  done
  println "$__self__cache__ups__out"
}
