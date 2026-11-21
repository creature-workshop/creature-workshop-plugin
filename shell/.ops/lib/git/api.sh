#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"
import "$SHELLOPS_DIR/lib/os/api.sh"
import "$SHELLOPS_DIR/lib/git/index.sh"
import "$SHELLOPS_DIR/lib/time/api.sh"

:<<'MODULE'
Local git repository helpers: diff operations, worktree
detection, and the reading and classification of the git operations a shell
command performs.

Uses PROJ (or GIT_REPO) as the repository root and GIT_REMOTE (default origin)
for fetch operations.
MODULE

# CONST: The lexer output's separator between an invocation's fields: a tab.
__git__TAB="$(printf '\t')"

: <<'CONST'
The lexer output's separator between an invocation's arguments: a control
character no shell word contains.
CONST
__git__WORD_SEPARATOR="$(printf '\037')"

__git__repo() {
  println "${GIT_REPO:-${PROJ:-.}}"
}

:<<'PUB_FUN'
Prints true when git can read the repository, false otherwise. Git cannot
read it when git is not installed, when the directory is not a repository,
and when git refuses the repository because another user owns its files.

  git__repository_readable  ->  true

Usage: git__repository_readable
PUB_FUN
git__repository_readable() {
  @succeeds __git__repository_readable__out __git__read_git_dir
  println "$__git__repository_readable__out"
}

: <<'FUN'
Asks git for the repository's git directory and discards the answer. Fails
when git cannot be run or cannot read the repository.
FUN
__git__read_git_dir() {
  git -C "$(__git__repo)" rev-parse --git-dir >/dev/null 2>&1
}

:<<'PUB_FUN'
Returns 0 when ref resolves to a commit object.

Usage: git__ref_exists <ref>
PUB_FUN
git__ref_exists() {
  git -C "$(__git__repo)" cat-file -e "${1}^{commit}" 2>/dev/null
}

:<<'PUB_FUN'
The commit <ref> resolves to. Non-zero when it resolves to none.

Usage: git__commit_of origin/main   # -> 9bd382fa...
PUB_FUN
git__commit_of() {
  git -C "$(__git__repo)" rev-parse --verify --quiet "${1}^{commit}"
}

:<<'PUB_FUN'
How many commits a walk from <ref> meets: in a shallow clone, the ones
down to its boundary. Non-zero when <ref> resolves to none.

Usage: git__commit_count HEAD   # -> 27
PUB_FUN
git__commit_count() {
  git -C "$(__git__repo)" rev-list --count "${1}^{commit}" 2>/dev/null
}

:<<'PUB_FUN'
The tree <ref> points at. Non-zero when the ref resolves to none.

Usage: git__tree_of origin/main   # -> 4b825dc6...
PUB_FUN
git__tree_of() {
  git -C "$(__git__repo)" rev-parse --verify --quiet "${1}^{tree}"
}

:<<'PUB_FUN'
Prints true when <ref_a> and <ref_b> hold the same files, false otherwise:
an empty commit on top of a tag holds what the tag holds, so two refs are
compared by tree rather than by commit. Non-zero when either resolves to none.

Usage: git__trees_match HEAD 1.2.3-rc.1
PUB_FUN
git__trees_match() {
  __git__trees_match__left="$(git__tree_of "$1")" || return 1
  __git__trees_match__right="$(git__tree_of "$2")" || return 1

  @succeeds __git__trees_match__out [ "$__git__trees_match__left" = "$__git__trees_match__right" ]
  println "$__git__trees_match__out"
}

:<<'PUB_FUN'
Prints the files whose content differs between the trees of <ref_a> and
<ref_b>, as a struct array of paths from the repository root; the empty array
when the trees match. Non-zero when either ref resolves to none.

  git__differing_files 1.2.0-beta.1 1.2.0-rc.1  ->  ["manifest.json"]

Usage: git__differing_files <ref_a> <ref_b>
PUB_FUN
git__differing_files() {
  __git__differing_files__listed="$(git -C "$(__git__repo)" diff --name-only "$1" "$2")" || return 1
  if ! @defined "$__git__differing_files__listed"; then
    @arr __git__differing_files__out
    println "$__git__differing_files__out"
    return 0
  fi

  @split __git__differing_files__out "$__git__differing_files__listed"
  println "$__git__differing_files__out"
}

:<<'PUB_FUN'
Prints true when <ref_a> and <ref_b> hold the same files outside <masked>, a
struct array of the paths a difference is allowed in, and false otherwise. A
masked path is spelled from the repository root, or absolute, as the release
files are. Non-zero when either ref resolves to none.

  git__trees_match_outside 1.2.0-beta.1 1.2.0-rc.1 '["manifest.json"]'  ->  true

Usage: git__trees_match_outside <ref_a> <ref_b> <masked>
PUB_FUN
git__trees_match_outside() {
  __git__trees_match_outside__differing="$(git__differing_files "$1" "$2")" || return 1
  @map __git__trees_match_outside__masked __git__path_from_root "$3"

  @all __git__trees_match_outside__out __git__path_masked "$__git__trees_match_outside__differing" "$__git__trees_match_outside__masked"
  println "$__git__trees_match_outside__out"
}

:<<'FUN'
@map callback: the wrapped path $1 spelled from the repository root, with the
root's own prefix dropped from an absolute one.

  __git__path_from_root '"/p/engine/Cargo.toml"'  ->  engine/Cargo.toml   (repository at /p)
FUN
__git__path_from_root() {
  @unwrap __git__path_from_root__path "$1"
  __git__path_from_root__root="$(__git__repo)"

  printf '%s\n' "${__git__path_from_root__path#"$__git__path_from_root__root"/}"
}

:<<'FUN'
@all predicate: succeeds when the wrapped path $1 is among the masked paths $2.
FUN
__git__path_masked() {
  @unwrap __git__path_masked__path "$1"

  @any __git__path_masked__any_1 __git__path_eq "$2" "$__git__path_masked__path"
  @is_true "$__git__path_masked__any_1"
}

:<<'FUN'
@any predicate: succeeds when the wrapped path $1 equals $2.
FUN
__git__path_eq() {
  @unwrap __git__path_eq__unwrap_2 "$1"
  [ "$__git__path_eq__unwrap_2" = "$2" ]
}

:<<'PUB_FUN'
The file at <path> as <ref> holds it. Non-zero when the ref holds no such
file.

Usage: git__file_at origin/main manifest.json
PUB_FUN
git__file_at() {
  git -C "$(__git__repo)" show "${1}:${2}"
}

:<<'PUB_FUN'
Prints the paths the tree of <ref> holds, as a struct array of paths from
the repository root in the order git lists them; the empty array when the
ref holds no file. Non-zero when the ref resolves to none.

  git__files_at store  ->  [".gitattributes", "kubernetes/guestbook/small/fe75...b0a5.yaml"]

Usage: git__files_at <ref>
PUB_FUN
git__files_at() {
  __git__files_at__listed="$(git -C "$(__git__repo)" ls-tree -r --name-only "$1")" || return 1
  if ! @defined "$__git__files_at__listed"; then
    @arr __git__files_at__out
    println "$__git__files_at__out"
    return 0
  fi

  @split __git__files_at__out "$__git__files_at__listed"
  println "$__git__files_at__out"
}

:<<'PUB_FUN'
ISO-8601 creation date of a tag (creatordate), or empty when the tag does not
exist.

Usage: git__tag_date <tag>   # git__tag_date v0.8.0 -> 2026-06-17T12:40:00+00:00
PUB_FUN
git__tag_date() {
  git -C "$(__git__repo)" for-each-ref --format='%(creatordate:iso-strict)' "refs/tags/$1"
}

:<<'PUB_FUN'
The repository's default branch, resolved from origin/HEAD. Falls back to "main"
when origin/HEAD is unset (e.g. a shallow clone that did not fetch it).

Usage: git__default_branch   # -> main
PUB_FUN
git__default_branch() {
  __git__default_branch__ref="$(git -C "$(__git__repo)" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"
  __git__default_branch__ref="${__git__default_branch__ref#origin/}"
  println "${__git__default_branch__ref:-main}"
}

:<<'PUB_FUN'
The checked-out branch, or nothing on a detached HEAD.

Usage: git__current_branch   # -> feat/some-slug, or ""
PUB_FUN
git__current_branch() {
  __git__current_branch__ref="$(git -C "$(__git__repo)" symbolic-ref --short HEAD 2>/dev/null)" || return 0
  println "$__git__current_branch__ref"
}

:<<'PUB_FUN'
Prints true when the repository is a shallow clone, one whose history
stops short of its root, and false otherwise.

  git__is_shallow   ->  false

Usage: git__is_shallow
PUB_FUN
git__is_shallow() {
  __git__is_shallow__common="$(git -C "$(__git__repo)" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  @succeeds __git__is_shallow__out [ -f "$__git__is_shallow__common/shallow" ]
  println "$__git__is_shallow__out"
}

:<<'PUB_FUN'
Prints true when the history reachable from the checked-out head goes
back to <since>: always in a full clone, and in a shallow clone when
every commit at its boundary is dated at or before <since>, so that no
commit after <since> is missing. Prints false otherwise, and fails when
<since> is no timestamp. git__remotes__ensure_history_since <since> makes
it true.

  git__history_reaches 2026-10-07T23:52:13Z   ->  true

Usage: git__history_reaches <since>
PUB_FUN
git__history_reaches() {
  if @is_false "$(git__is_shallow)"; then
    @true __git__history_reaches__out
    println "$__git__history_reaches__out"
    return 0
  fi
  __git__history_reaches__since="$(time__epoch_of "$1")" || return 1
  __git__history_reaches__boundary="$(git -C "$(__git__repo)" rev-list --max-parents=0 --format=%ct HEAD 2>/dev/null | grep -v '^commit ' | sort -n | tail -n 1)"
  @succeeds __git__history_reaches__out [ "${__git__history_reaches__boundary:-0}" -le "$__git__history_reaches__since" ]
  println "$__git__history_reaches__out"
}

:<<'PUB_FUN'
List paths changed on the head side since base diverged (three-dot diff).

Usage: git__diff_name_only <base-ref> <head-ref>
PUB_FUN
git__diff_name_only() {
  git -C "$(__git__repo)" diff --name-only "${1}...${2}"
}

:<<'PUB_FUN'
List what changed between two commits' trees, one "<status>TAB<path>" line
per file with the status letter git gives it (A, M, D, T), a rename spelled
as its delete and its add. A two-commit comparison, not a three-dot one: it
names every file whose content differs between the two trees, whichever
side changed it.

  git__diff_name_status 9fa43442 HEAD
  ->  M	lib/string/api.sh
      A	lib/string/new.sh

Usage: git__diff_name_status <base-commit> <head-commit>
PUB_FUN
git__diff_name_status() {
  git -C "$(__git__repo)" diff --name-status --no-renames "$1" "$2"
}

:<<'PUB_FUN'
List the paths git reports as added (status A) on the head side since base
diverged. A rename or copy is not an addition, so it is excluded.

Usage: git__diff_added_name_only <base-ref> <head-ref>
PUB_FUN
git__diff_added_name_only() {
  git -C "$(__git__repo)" diff --diff-filter=A --name-only "${1}...${2}"
}

:<<'PUB_FUN'
Prints the paths under <dir> that <ref> has added since HEAD forked from it,
one per line. A file <ref> renamed counts under its new name, since that name
is new to HEAD. Prints nothing when <ref> resolves to no commit.

  git__added_upstream origin/main docs/decisions
    ->  docs/decisions/000035-a-seed.md

Usage: git__added_upstream <ref> <dir>
PUB_FUN
git__added_upstream() {
  git__ref_exists "$1" || return 0

  git -C "$(__git__repo)" diff \
    --no-renames \
    --diff-filter=A \
    --name-only \
    "HEAD...$1" \
    -- "$2"
}

:<<'PUB_FUN'
Print the subject and body of every commit in <range>, one after another.

A range git cannot resolve prints nothing rather than failing. The baseline of a
pushed range can be missing for reasons that are not this caller's problem: a
force-push that dropped it, or a shallow clone that never fetched it.

Usage: git__commit_text "abc123..def456"
PUB_FUN
git__commit_text() {
  git -C "$(__git__repo)" log --format='%s%n%b' "$1" 2>/dev/null || true
}

:<<'PUB_FUN'
Print the range covering the last <depth> commits, as <sha>..HEAD, or nothing
when the history does not reach back that far.

For callers with no better baseline to work from. Emptiness has to be the answer
for a young or shallow repository, since HEAD~<depth> would otherwise name a
commit git cannot resolve and every reader of the range would have to cope.

--verify --quiet is what makes that reliable: a bare `rev-parse HEAD~10` prints
its own argument back when it cannot resolve it, so the caller gets the string
"HEAD~10" and a failure at the same time.

Usage: git__recent_range 10
PUB_FUN
git__recent_range() {
  __git__recent_range__base="$(git -C "$(__git__repo)" rev-parse --verify --quiet "HEAD~${1}" || true)"

  if @defined "$__git__recent_range__base"; then
    printf '%s..HEAD\n' "$__git__recent_range__base"
  fi
}

:<<'PUB_FUN'
Print the first line of path at ref (for shebang checks on deleted files).

Usage: git__show_first_line <ref> <path>
PUB_FUN
git__show_first_line() {
  git -C "$(__git__repo)" show "${1}:${2}" 2>/dev/null | head -n1
}

:<<'PUB_FUN'
Print the whole of <path> as it stands at <ref>. A path or ref git cannot
resolve prints nothing rather than failing: the file did not exist there, or
the ref was never fetched, and either way the caller has no content to read.

Usage: git__show_file <ref> <path>
PUB_FUN
git__show_file() {
  git -C "$(__git__repo)" show "${1}:${2}" 2>/dev/null || true
}

:<<'PUB_FUN'
Print <path> as the index spells it: relative to the repository root.

A pathspec on the command line may be absolute, but an index or tree lookup
(`git show :<path>`) may not, so anything reading a staged blob converts first.
A path already relative is returned unchanged.

Usage: git__index_path <path>
PUB_FUN
git__index_path() {
  __git__index_path__repo="$(__git__repo)"
  printf '%s\n' "${1#"$__git__index_path__repo"/}"
}

:<<'PUB_FUN'
Print the new-file line numbers added to <path> in the staged diff (--cached),
one per line. Read from the -U0 hunk headers: `@@ -a,b +c,d @@` adds the d lines
starting at c (a single-line hunk omits ,d and adds one line at c).

Usage: git__staged_added_lines <path>
PUB_FUN
git__staged_added_lines() {
  git -C "$(__git__repo)" diff --cached -U0 -- "$1" \
    | awk -f "$SHELLOPS_DIR/lib/git/added_lines.awk"
}

:<<'PUB_FUN'
Print the paths the staged diff (--cached) adds, one per line, each relative
to the repository root. A rename or a copy is not an addition, so it is
excluded.

  git__staged_added_files  ->  lib/string/new.sh

Usage: git__staged_added_files
PUB_FUN
git__staged_added_files() {
  git -C "$(__git__repo)" diff --cached --find-renames --diff-filter=A --name-only
}

:<<'PUB_FUN'
Prints the submodule paths that .gitmodules declares, one per line: the
repository's by default, or those of the worktree at <root>.

Usage: git__submodule_paths
       git__submodule_paths "$worktree"
PUB_FUN
git__submodule_paths() {
  __git__submodule_paths__repo="${1:-$(__git__repo)}"
  __git__submodule_paths__modules="$__git__submodule_paths__repo/.gitmodules"
  [ -f "$__git__submodule_paths__modules" ] || return 0
  git -C "$__git__submodule_paths__repo" config --file "$__git__submodule_paths__modules" --get-regexp 'submodule\..*\.path' \
    | awk '{print $2}'
}

:<<'PUB_FUN'
Prints the repository the .gitmodules of the tree <dir> names for the
submodule at <path>, as it is written there, and nothing when the tree has
no .gitmodules or it names none for that path. The tree need not be a
repository: a checkout's files are enough.

  git__submodule_url /p/.ops/cache/strata/73e6... shell/.logs  ->  ../shell-logs.git

args:
  $1  The tree
  $2  The submodule's path inside it
PUB_FUN
git__submodule_url() {
  __git__submodule_url__modules="$1/.gitmodules"
  [ -f "$__git__submodule_url__modules" ] || return 0
  __git__submodule_url__section="$(git config --file "$__git__submodule_url__modules" --get-regexp '^submodule\..*\.path$' "^$2\$" 2>/dev/null)" || return 0
  __git__submodule_url__section="${__git__submodule_url__section%% *}"
  __git__submodule_url__section="${__git__submodule_url__section%.path}"
  git config --file "$__git__submodule_url__modules" "$__git__submodule_url__section.url" 2>/dev/null || return 0
}

:<<'PUB_FUN'
Print the files under a directory, one per line, relative to it and in byte
order: the git index when the directory is inside a work tree, otherwise a
hidden-path-pruned find (for non-repo trees, e.g. test fixtures). Both
branches list in the same order, so a caller's output never depends on the
filesystem.

args:
  $1  The directory to list (defaults to the repo root)

Usage: git__tracked_files "$dir"
PUB_FUN
git__tracked_files() {
  __git__tracked_files__dir="${1:-$(__git__repo)}"
  if git -C "$__git__tracked_files__dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$__git__tracked_files__dir" ls-files
  else
    __git__tracked_files__find "$__git__tracked_files__dir"
  fi
}

:<<'FUN'
Print the non-hidden files under a directory outside any work tree, relative
to it and in byte order -- the order `git ls-files` lists in.

Usage: __git__tracked_files__find "$dir"
FUN
__git__tracked_files__find() {
  (
    cd "$1" \
      && find . -type f ! -path '*/.*' \
      | sed 's|^\./||' \
      | LC_ALL=C sort
  )
}

:<<'PUB_FUN'
Prints the root of the main worktree <path> lies in -- the primary checkout,
whose <root>/.git is a directory, unlike a linked worktree's .git file -- or
nothing for a path in a linked worktree or outside any repository. A path that
does not exist yet resolves through its nearest existing ancestor.

Usage: git__main_worktree_root /repo/new/file.txt   # -> /repo
PUB_FUN
git__main_worktree_root() {
  __git__main_worktree_root__dir="$(os__existing_dir "$1")"
  [ -d "$__git__main_worktree_root__dir" ] || return 0
  __git__main_worktree_root__root="$(git -C "$__git__main_worktree_root__dir" rev-parse --show-toplevel 2>/dev/null)" || return 0
  [ -d "$__git__main_worktree_root__root/.git" ] || return 0
  println "$__git__main_worktree_root__root"
}

:<<'PUB_FUN'
Prints true when <path> lies in a main worktree, false for a linked worktree
and for a path outside any repository.

Usage: git__is_main_worktree "$dir"
PUB_FUN
git__is_main_worktree() {
  @succeeds __git__is_main_worktree__out @defined "$(git__main_worktree_root "$1")"
  println "$__git__is_main_worktree__out"
}

:<<'PUB_FUN'
Prints the exclude file of the repository <dir> lies in -- the ignore list
git keeps beside .gitignore for one clone alone, read by git and by cargo --
or nothing for a directory outside any repository. The file need not exist.

Usage: git__info_exclude /repo/crate   # -> /repo/.git/info/exclude
PUB_FUN
git__info_exclude() {
  __git__info_exclude__file="$(git -C "$1" rev-parse --path-format=absolute --git-path info/exclude 2>/dev/null)" || return 0
  println "$__git__info_exclude__file"
}

:<<'PUB_FUN'
Prints true when <branch> is a local branch of the repository, false otherwise.

Usage: git__branch_exists feat/some-slug
PUB_FUN
git__branch_exists() {
  @succeeds __git__branch_exists__out git -C "$(__git__repo)" show-ref --verify --quiet "refs/heads/$1"
  println "$__git__branch_exists__out"
}

:<<'PUB_FUN'
Prints true when the worktree at <path> has no uncommitted or untracked
changes, false otherwise. Submodule state does not count: a submodule's HEAD
is the pointer's business, not the worktree's.

Usage: git__worktree_clean "$path"
PUB_FUN
git__worktree_clean() {
  __git__worktree_clean__status="$(git -C "$1" status --porcelain --ignore-submodules=all)"
  if @defined "$__git__worktree_clean__status"; then
    @false __git__worktree_clean__out
    println "$__git__worktree_clean__out"
  else
    @true __git__worktree_clean__out
    println "$__git__worktree_clean__out"
  fi
}

:<<'PUB_FUN'
Prints true when <branch> tracks a remote branch that no longer exists, false
when it tracks nothing or the remote branch is still there. Reads the
tracking state as of the last fetch; fetch with --prune first for a current
answer.

Usage: git__remote_branch_gone feat/some-slug
PUB_FUN
git__remote_branch_gone() {
  __git__remote_branch_gone__upstream="$(git -C "$(__git__repo)" for-each-ref --format='%(upstream)' "refs/heads/$1")"
  __git__remote_branch_gone__track="$(git -C "$(__git__repo)" for-each-ref --format='%(upstream:track)' "refs/heads/$1")"
  if ! @defined "$__git__remote_branch_gone__upstream"; then
    @false __git__remote_branch_gone__out
    println "$__git__remote_branch_gone__out"
    return 0
  fi
  @succeeds __git__remote_branch_gone__out [ "$__git__remote_branch_gone__track" = "[gone]" ]
  println "$__git__remote_branch_gone__out"
}

:<<'PUB_FUN'
Fetches <remote> (default: GIT_REMOTE or origin) and drops the tracking refs
of branches it has deleted, so git__remote_branch_gone and git__branch_merged
answer for the remote as it is now. A repository with no such remote fetches
nothing.

Usage: git__fetch_prune
       git__fetch_prune upstream
PUB_FUN
git__fetch_prune() {
  __git__fetch_prune__remote="${1:-${GIT_REMOTE:-origin}}"
  if git -C "$(__git__repo)" remote get-url "$__git__fetch_prune__remote" >/dev/null 2>&1; then
    git -C "$(__git__repo)" fetch --quiet --prune "$__git__fetch_prune__remote"
  fi
}

:<<'PUB_FUN'
Deletes the local <branch>, merged or not. Deleting a branch that does not
exist is not an error: the state asked for is the state reached either way.

Usage: git__branch_delete feat/some-slug
PUB_FUN
git__branch_delete() {
  if @is_true "$(git__branch_exists "$1")"; then
    git -C "$(__git__repo)" branch -D "$1"
  fi
}

:<<'PUB_FUN'
Checks out the submodule at <path> in the worktree at <root> (default: the
repository) when its checkout is missing, at the commit the worktree records.
An existing checkout is left as it stands, however its HEAD sits: moving it
back to the recorded commit would discard a bump in progress.

Usage: git__submodule_init shell/.ops
       git__submodule_init shell/.ops "$worktree"
PUB_FUN
git__submodule_init() {
  __git__submodule_init__root="${2:-$(__git__repo)}"
  if [ -e "$__git__submodule_init__root/$1/.git" ]; then
    return 0
  fi
  git -C "$__git__submodule_init__root" submodule update --init --recursive "$1"
}

:<<'PUB_FUN'
Prints true when <branch>'s work is on <target> (default: the remote's default
branch), false otherwise. The work is there when the branch's tip is an
ancestor of the target, or when the branch was pushed and the remote has since
deleted it -- which is what a squash merge leaves, since the squashed commit is
not the branch's own.

Usage: git__branch_merged feat/some-slug            # against origin/main
       git__branch_merged feat/some-slug origin/dev
PUB_FUN
git__branch_merged() {
  __git__branch_merged__target="${2:-${GIT_REMOTE:-origin}/$(git__default_branch)}"
  if git -C "$(__git__repo)" merge-base --is-ancestor "$1" "$__git__branch_merged__target" 2>/dev/null; then
    @true __git__branch_merged__out
    println "$__git__branch_merged__out"
    return 0
  fi
  git__remote_branch_gone "$1"
}

:<<'PUB_FUN'
Checks out <branch> at <path> as a linked worktree of the repository. A branch
that does not exist yet is created from <start-point> (default: the remote's
default branch, fetched first so it starts at the remote's current tip).

Usage: git__worktree_add "$path" feat/some-slug
       git__worktree_add "$path" feat/some-slug origin/dev
PUB_FUN
git__worktree_add() {
  __git__worktree_add__start="${3:-${GIT_REMOTE:-origin}/$(git__default_branch)}"
  if @is_true "$(git__branch_exists "$2")"; then
    git -C "$(__git__repo)" worktree add "$1" "$2"
    return 0
  fi
  __git__fetch_remote_of "$__git__worktree_add__start"
  git -C "$(__git__repo)" worktree add -b "$2" "$1" "$__git__worktree_add__start"
}

:<<'FUN'
Fetches the remote a ref such as origin/main names. A ref naming no configured
remote fetches nothing.
FUN
__git__fetch_remote_of() {
  __git__fetch_remote_of__remote="${1%%/*}"
  if git -C "$(__git__repo)" remote get-url "$__git__fetch_remote_of__remote" >/dev/null 2>&1; then
    git -C "$(__git__repo)" fetch --quiet "$__git__fetch_remote_of__remote"
  fi
}

:<<'PUB_FUN'
Checks out <commit> at <path> as a linked worktree with a detached HEAD: the
tree of one commit to read or run, no branch made or moved.

Usage: git__worktree_checkout "$path" "$sha"
PUB_FUN
git__worktree_checkout() {
  git -C "$(__git__repo)" worktree add --quiet --detach "$1" "$2"
}

:<<'PUB_FUN'
Prints the commit the worktree at <path> is checked out at. Non-zero when
<path> is no worktree.

Usage: git__worktree_head "$path"   # -> 9a02...
PUB_FUN
git__worktree_head() {
  git -C "$1" rev-parse --verify --quiet 'HEAD^{commit}'
}

:<<'PUB_FUN'
Deletes the linked worktree at <path> and drops it from the repository's
worktree list. This is the sequence `git worktree remove` refuses on a tree
holding a submodule, --force included. The branch the worktree had checked
out is left in place. No safety check is made here: the caller decides what a
tree must satisfy before it goes.

Usage: git__worktree_remove "$path"
PUB_FUN
git__worktree_remove() {
  rm -rf "$1"
  git -C "$(__git__repo)" worktree prune
}

:<<'PUB_FUN'
Drops from the repository's worktree list the linked worktrees whose
directories are gone.

Usage: git__worktree_prune
PUB_FUN
git__worktree_prune() {
  git -C "$(__git__repo)" worktree prune
}

:<<'PUB_FUN'
Prints the push classification of a command against a space-separated
protected-branch list: "protected" when a push names a protected branch in a
refspec or branch argument, "bare<TAB>path" when a push gives no refspec (path
is its `git -C` argument, possibly empty), "none" otherwise. Command operators
split the command into segments judged alone; a protected finding outranks a
bare one.

Usage: git__push_class "$command" "main master"
PUB_FUN
git__push_class() {
  println "$1" \
    | awk \
      -v branches="$2" \
      -f "$SHELLOPS_DIR/lib/git/shell_lex.awk" \
      -f "$SHELLOPS_DIR/lib/git/git_lex.awk" \
      -f "$SHELLOPS_DIR/lib/git/push_class.awk"
}

:<<'PUB_FUN'
Prints the git invocations a shell command runs as a struct array, one element
per simple command whose command word is git, in command order:

  dir   the path given to `git -C`, or empty
  verb  the git verb, or empty for a bare `git`
  args  the verb's arguments, a string array

The shell-aware lexer does the reading: command operators and `$( )`,
backtick, and process substitutions split the command; an assignment or
wrapper before the command word, git's own flags before the verb (-C and -c
carry an argument), and redirections are no part of the invocation; quoted
arguments and heredoc bodies never stand as commands.

  git__command_invocations 'cd x && git -C /r pull --ff-only 2>&1; echo "$(git log -1)"'
  -> [{"dir":"/r","verb":"pull","args":["--ff-only"]},
      {"dir":"","verb":"log","args":["-1"]}]
PUB_FUN
git__command_invocations() {
  println "$1" \
    | awk \
      -v sep="$__git__WORD_SEPARATOR" \
      -f "$SHELLOPS_DIR/lib/git/shell_lex.awk" \
      -f "$SHELLOPS_DIR/lib/git/git_lex.awk" \
      -f "$SHELLOPS_DIR/lib/git/invocations.awk" \
    | __git__collect_invocations
}

:<<'FUN'
Reads the lexer's invocation lines on stdin into the struct array
git__command_invocations prints. Runs at the end of that pipeline, so it prints
the accumulator itself rather than handing it back to a caller in another
shell.
FUN
__git__collect_invocations() {
  @arr __git__collect_invocations__list
  while IFS= read -r __git__collect_invocations__line; do
    __git__collect_invocations__one="$(__git__invocation "$__git__collect_invocations__line")"
    @push __git__collect_invocations__list "$__git__collect_invocations__list" "$__git__collect_invocations__one"
  done
  println "$__git__collect_invocations__list"
}

:<<'FUN'
Builds one invocation struct from the lexer's <dir>TAB<verb>TAB<args> line.

  __git__invocation "/r<TAB>pull<TAB>--ff-only<SEP>origin"
  -> {"dir":"/r","verb":"pull","args":["--ff-only","origin"]}
FUN
__git__invocation() {
  __git__invocation__dir="${1%%"$__git__TAB"*}"
  __git__invocation__rest="${1#*"$__git__TAB"}"
  __git__invocation__verb="${__git__invocation__rest%%"$__git__TAB"*}"
  __git__invocation__args="${__git__invocation__rest#*"$__git__TAB"}"
  @split __git__invocation__split_3 "$__git__invocation__args" "$__git__WORD_SEPARATOR"
  @obj __git__invocation__out \
    '.dir' "$__git__invocation__dir" \
    '.verb' "$__git__invocation__verb" \
    '.args' "$__git__invocation__split_3"
  println "$__git__invocation__out"
}
