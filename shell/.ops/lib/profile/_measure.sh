#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/git/remotes.sh" \
  "$SHELLOPS_DIR/lib/profile/api.sh" \
  "$SHELLOPS_DIR/lib/self/shellops.sh"

: <<'MODULE'
Measuring what a repository's profiling declaration names on a tree: each
command under each profiler, on a fresh worktree of a commit prepared alike,
its submodules checked out and one boot before the first command, so the
measurements of two commits compare. A row keeps the command's cli words,
its exit status and the totals the profiler reports, and a command can be
run under one NAME=value assignment, so the same tree can be measured as is
and under a variant.
MODULE

# CONST: The measurements of the tree being measured, a struct object by profiler; profile__measure__tree fills it through its callback.
__profile__measure__MEASURED=""

# CONST: The NAME=value the commands of the tree being measured run under, or nothing; profile__measure__tree sets it for __profile__measure__warm_tree and __profile__measure__command.
__profile__measure__UNDER=""

: <<'PUB_FUN'
Measures the declared commands on this head: the commit the repository is
checked out at, as a fresh worktree prepared the way the base's is.

  $1  The profiling declaration
PUB_FUN
profile__measure__head() {
  profile__measure__commit "$(git__worktree_head "$PROJ")" "$1"
}

: <<'PUB_FUN'
Measures the declared commands on the merge base <sha>: fetches it if the
clone is too shallow to hold it, then measures it as a fresh worktree.

  $1  The commit to measure   $2  The profiling declaration
PUB_FUN
profile__measure__base() {
  git__remotes__ensure_refs_for_diff "$1" HEAD
  profile__measure__commit "$1" "$2"
}

: <<'PUB_FUN'
Measures the declared commands on a fresh worktree of <sha>: checks the
commit out as a throwaway worktree with the submodules it declares, boots
it once, measures, and removes the worktree. The head and the base both
come through here, so the two are prepared alike and their measurements
compare: the job's own checkout, with its restored cache and its review
context, is never what is measured. The worktree goes whether the
measurement succeeded or not, and a failed one fails this call; a checkout
that cannot be made leaves nothing behind either.

  $1  The commit to measure   $2  The profiling declaration
  $3  One NAME=value the commands run under, or nothing
PUB_FUN
profile__measure__commit() {
  __profile__measure__commit__dir="$(mktemp -d)"
  if ! git__worktree_checkout "$__profile__measure__commit__dir" "$1"; then
    rm -rf "$__profile__measure__commit__dir"
    return 1
  fi
  __profile__measure__checkout_submodules "$__profile__measure__commit__dir"

  __profile__measure__commit__status=0
  profile__measure__tree "$__profile__measure__commit__dir" "$2" "${3-}" || __profile__measure__commit__status=$?

  git__worktree_remove "$__profile__measure__commit__dir"
  return "$__profile__measure__commit__status"
}

: <<'PUB_FUN'
Measures the declared commands on the tree at <dir>: a struct object by
profiler, each a struct array of rows {command, status, <measure>...} in
the declaration's order, the status the command's own exit status. A
command runs as the tree's own ops, through the shellops the tree vendors
or the tree itself when it is shellops (self__shellops__of), so an older
tree answers for itself, and under <assignment> when one is given.

  profile__measure__tree /path/to/shellops "$declaration"
    ->  {"forks":[{"command":"test plan","forks":2506,"starts":684,"status":0}, ...]}

  $1  The tree   $2  The profiling declaration
  $3  One NAME=value the commands run under, or nothing
PUB_FUN
profile__measure__tree() {
  __profile__measure__UNDER="${3-}"
  __profile__measure__warm_tree "$1"
  @obj __profile__measure__MEASURED
  @foreach __profile__measure__profiler "$(profile__declared_profilers "$2")" "$1" "$2"
  println "$__profile__measure__MEASURED"
}

: <<'PUB_FUN'
Prints true when a key of a measured row is a measure, false for the
command's name and its exit status, which the row carries beside them.
PUB_FUN
profile__is_measure() {
  if [ "$1" = command ] || [ "$1" = status ]; then
    println false
  else
    println true
  fi
}

: <<'FUN'
Checks out every submodule the tree at <dir> declares. A linked worktree
starts with none, and a tree whose boot reads a file from one (shellops
sources its log library from shell/.logs) exits at once without them, which
measures as a command of two forks. Git's progress goes to stderr, so the
caller's stdout stays the measurement alone.

  $1  The tree
FUN
__profile__measure__checkout_submodules() {
  git__submodule_paths "$1" | while IFS= read -r __profile__measure__checkout_submodules__path; do
    git__submodule_init "$__profile__measure__checkout_submodules__path" "$1" >&2
  done
}

: <<'FUN'
Boots the tree at <dir> once before anything is measured on it, so the
compiled tree and the fetched dependencies it lays down on first use are
not counted against the first command. A fresh worktree of the merge base
would otherwise measure its own boot. The boot runs under the assignment
the tree is measured under, so what it lays down is what the commands use.
FUN
__profile__measure__warm_tree() {
  __profile__measure__warm_tree__shellops="$(self__shellops__of "$1")"
  # shellcheck disable=SC2016,SC2086  # the inner shell expands SHELLOPS_DIR from the environment it is given; the assignment is one word or none
  env $__profile__measure__UNDER SHELLOPS_DIR="$__profile__measure__warm_tree__shellops" PROJ="$1" \
    bash -c '. "$SHELLOPS_DIR/.envrc"' >/dev/null 2>&1 || true
}

: <<'FUN'
@foreach callback: measures every command declared under the wrapped
<profiler> on the tree, and records the rows under the profiler's name.

  $1  The profiler, wrapped   $2  The tree   $3  The declaration
FUN
__profile__measure__profiler() {
  @unwrap __profile__measure__profiler__name "$1"
  @map __profile__measure__profiler__rows __profile__measure__command \
    "$(profile__declared_commands "$3" "$__profile__measure__profiler__name")" \
    "$__profile__measure__profiler__name" \
    "$2"
  @set __profile__measure__MEASURED "$__profile__measure__MEASURED" "$__profile__measure__profiler__name" "$__profile__measure__profiler__rows"
}

: <<'FUN'
@map callback: the totals of one command (wrapped) under <profiler> on the
tree <dir>, with the command named and its exit status kept, since a
command that fails measures as cheap. The words are the declaration's, and
splitting them into the command's arguments is the point; the command runs
under the assignment profile__measure__tree was given, when one was.

  $1  The command's cli words, wrapped   $2  The profiler   $3  The tree
FUN
__profile__measure__command() {
  @unwrap __profile__measure__command__words "$1"
  __profile__measure__command__trace="$(mktemp)"
  __profile__measure__command__shellops="$(self__shellops__of "$3")"
  __profile__measure__command__status=0

  # shellcheck disable=SC2086  # the words split into the command's arguments, and the assignment is one word or none
  profile__run "$2" "$__profile__measure__command__trace" \
    env $__profile__measure__UNDER SHELLOPS_DIR="$__profile__measure__command__shellops" PROJ="$3" "$__profile__measure__command__shellops/cli/"$__profile__measure__command__words \
    2>/dev/null || __profile__measure__command__status=$?

  __profile__measure__command__totals="$(profile__totals "$2" "$__profile__measure__command__trace")"
  rm -f "$__profile__measure__command__trace"
  @set __profile__measure__command__out "$__profile__measure__command__totals" \
    '.command' "$__profile__measure__command__words" \
    '.status' "$__profile__measure__command__status"
  println "$__profile__measure__command__out"
}
