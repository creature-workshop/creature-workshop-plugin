#!/bin/sh

import "$SHELLOPS_DIR/lib/git/api.sh"
import "$SHELLOPS_DIR/lib/git/credential.sh"

: <<'MODULE'
Remotes beyond origin: naming one for a repository elsewhere, letting the
clone sign in to that host as a bot, pushing a tag to a remote, and publishing a
branch that carries one empty commit. A tag the remote already holds at the
same commit is a quiet success; at another commit it is a refusal.
MODULE

: <<'CONST'
How many older commits one round fetches beyond every boundary. A round
is a round trip to the remote, and a hundred commits is a small fetch, so
the step is large enough that a week of a busy repository's history
arrives in one round.
CONST
__git__remotes__HISTORY_FETCH_STEP=100

: <<'PUB_FUN'
Points the remote <name> at <url>, adding the remote when the clone has none
by that name and moving it when it has. Prints nothing.

Usage: git__remote_set <name> <url>
PUB_FUN
git__remote_set() {
  if git -C "$(__git__repo)" remote get-url "$1" >/dev/null 2>&1; then
    git -C "$(__git__repo)" remote set-url "$1" "$2"
    return
  fi

  git -C "$(__git__repo)" remote add "$1" "$2"
}

: <<'PUB_FUN'
Lets every request the clone makes to the server <url> sign in as <user>
with the token the variable <token_env> holds, by naming shellops's
credential helper for the server on the repository's own configuration.
git asks the helper at each request, so the token is in no file and in no
remote's URL, and no trace or listing of the remotes shows it.

  git__authorize_host https://gitlab.com oauth2 GITLAB_PROMOTION_TOKEN

Usage: git__authorize_host <url> <user> <token_env>
PUB_FUN
git__authorize_host() {
  git__credential__helper_set "$1" "$(git__credential__command "$2" "$3")"
}

: <<'PUB_FUN'
Pushes the tag <tag> this clone holds to <remote>. A tag the remote already
holds at the same commit is nothing to do and succeeds; one it holds at
another commit is refused, since a tag names one commit for good. Non-zero
when the push is refused.

Usage: git__push_tag <remote> <tag>
PUB_FUN
git__push_tag() {
  git -C "$(__git__repo)" push --quiet "$1" "refs/tags/${2}:refs/tags/${2}"
}

: <<'PUB_FUN'
Publishes <branch> on <remote> as one empty commit on top of <ref>, carrying
<message>, and prints the commit. The commit is written straight into the
object database, so the checkout keeps the branch, index and working tree it
had. Non-zero when the ref resolves to none or the remote refuses the push:
a branch the remote already holds elsewhere is refused, never forced.

Usage: git__publish_empty_commit origin origin/main promote/1.2.0-rc.1 "promote: 1.2.0-rc.1"
PUB_FUN
git__publish_empty_commit() {
  __git__publish_empty_commit__tip="$(git__commit_of "$2")" || return 1
  __git__publish_empty_commit__tree="$(git__tree_of "$2")" || return 1
  __git__publish_empty_commit__commit="$(git -C "$(__git__repo)" commit-tree \
    "$__git__publish_empty_commit__tree" \
    -p "$__git__publish_empty_commit__tip" \
    -m "$4"
  )" || return 1

  git -C "$(__git__repo)" push --quiet "$1" "${__git__publish_empty_commit__commit}:refs/heads/${3}" || return 1
  println "$__git__publish_empty_commit__commit"
}

: <<'PUB_FUN'
Prints the host the remote <name> points at, with the user and the port left
off. Non-zero, printing nothing, when the clone has no remote by that name or
its URL names no host.

  git__remotes__host origin  ->  gitlab.example.com
    (for ssh://git@gitlab.example.com:2223/group/repo.git
     or git@gitlab.example.com:group/repo.git)

Usage: git__remotes__host <name>
PUB_FUN
git__remotes__host() {
  __git__remotes__host__url="$(__git__remote_url "$1")" || return 1
  case "$__git__remotes__host__url" in
    *://*) __git__remotes__host__host="$(__git__url_host "$__git__remotes__host__url")" ;;
    *@*:*) __git__remotes__host__host="$(__git__scp_host "$__git__remotes__host__url")" ;;
    *) return 1 ;;
  esac
  @defined "$__git__remotes__host__host" || return 1
  println "$__git__remotes__host__host"
}

: <<'PUB_FUN'
Prints the repository path the remote <name> points at, every group included,
without the leading slash or the trailing .git. Non-zero, printing nothing,
when the clone has no remote by that name or its URL names no path.

  git__remotes__path origin  ->  group/sub/repo
    (for ssh://git@gitlab.example.com:2223/group/sub/repo.git
     or git@gitlab.example.com:group/sub/repo.git)

Usage: git__remotes__path <name>
PUB_FUN
git__remotes__path() {
  __git__remotes__path__url="$(__git__remote_url "$1")" || return 1
  case "$__git__remotes__path__url" in
    *://*) __git__remotes__path__path="$(__git__url_path "$__git__remotes__path__url")" ;;
    *@*:*) __git__remotes__path__path="$(__git__scp_path "$__git__remotes__path__url")" ;;
    *) return 1 ;;
  esac
  @defined "$__git__remotes__path__path" || return 1
  println "$__git__remotes__path__path"
}

: <<'FUN'
Prints the URL the remote <name> points at. Non-zero when the clone has none
by that name.

Usage: __git__remote_url <name>
FUN
__git__remote_url() {
  git -C "$(__git__repo)" remote get-url "$1" 2>/dev/null
}

: <<'FUN'
The host of a URL with a scheme: what follows the scheme and any user, up to
the port or the path.

  __git__url_host ssh://git@gitlab.example.com:2223/group/repo.git  ->  gitlab.example.com
FUN
__git__url_host() {
  __git__url_host__rest="${1#*://}"
  __git__url_host__rest="${__git__url_host__rest#*@}"
  __git__url_host__rest="${__git__url_host__rest%%/*}"
  println "${__git__url_host__rest%%:*}"
}

: <<'FUN'
The host of an scp-like URL: what sits between the user's @ and the colon.

  __git__scp_host git@gitlab.example.com:group/repo.git  ->  gitlab.example.com
FUN
__git__scp_host() {
  __git__scp_host__rest="${1#*@}"
  println "${__git__scp_host__rest%%:*}"
}

: <<'FUN'
The repository path of a URL with a scheme: what follows the host and port,
without the trailing .git. Nothing when the URL names a host alone.

  __git__url_path ssh://git@gitlab.example.com:2223/group/repo.git  ->  group/repo
FUN
__git__url_path() {
  __git__url_path__rest="${1#*://}"
  __git__url_path__rest="${__git__url_path__rest#*@}"
  case "$__git__url_path__rest" in
    */*) __git__url_path__path="${__git__url_path__rest#*/}" ;;
    *) __git__url_path__path="" ;;
  esac
  __git__trimmed_path "$__git__url_path__path"
}

: <<'FUN'
The repository path of an scp-like URL: what follows the colon, without the
trailing .git.

  __git__scp_path git@gitlab.example.com:group/repo.git  ->  group/repo
FUN
__git__scp_path() {
  __git__trimmed_path "${1#*:}"
}

: <<'FUN'
A repository path with the trailing .git and slash taken off.

  __git__trimmed_path group/repo.git/  ->  group/repo
FUN
__git__trimmed_path() {
  __git__trimmed_path__path="${1%/}"
  println "${__git__trimmed_path__path%.git}"
}

: <<'PUB_FUN'
Prints true when <remote> holds <ref>, false when it does not. Non-zero when
the remote cannot be asked, so a missing ref and an unreachable remote never
read the same.

  git__remotes__has_ref origin refs/notes/testing-trace  ->  true

Usage: git__remotes__has_ref <remote> <ref>
PUB_FUN
git__remotes__has_ref() {
  __git__remotes__has_ref__status=0
  git -C "$(__git__repo)" ls-remote --exit-code "$1" "$2" >/dev/null 2>&1 \
    || __git__remotes__has_ref__status=$?
  if [ "$__git__remotes__has_ref__status" -eq 0 ]; then
    @true __git__remotes__has_ref__out
    println "$__git__remotes__has_ref__out"
    return 0
  fi
  if [ "$__git__remotes__has_ref__status" -eq 2 ]; then
    @false __git__remotes__has_ref__out
    println "$__git__remotes__has_ref__out"
    return 0
  fi
  return "$__git__remotes__has_ref__status"
}

: <<'PUB_FUN'
Fetches <ref> from <remote> into the same name here, replacing what the
clone held under it. Non-zero when the remote does not hold the ref or
cannot be asked; git__remotes__has_ref says which beforehand.

  git__remotes__fetch_ref origin refs/notes/testing-trace

Usage: git__remotes__fetch_ref <remote> <ref>
PUB_FUN
git__remotes__fetch_ref() {
  git -C "$(__git__repo)" fetch -q "$1" "+$2:$2"
}

: <<'PUB_FUN'
Fetches each of <ref...> from <remote> with its history back to <since>,
so that a shallow clone reaches that far. Non-zero when the remote cannot
be asked or does not hold a ref.

  git__remotes__fetch_since origin 2026-10-07T23:52:13Z 04ebe6f9... 810836d2...

Usage: git__remotes__fetch_since <remote> <since> <ref...>
PUB_FUN
git__remotes__fetch_since() {
  __git__remotes__fetch_since__remote="$1"
  __git__remotes__fetch_since__since="$2"
  shift 2
  git -C "$(__git__repo)" fetch --quiet \
    --shallow-since="$__git__remotes__fetch_since__since" \
    "$__git__remotes__fetch_since__remote" \
    "$@"
}

: <<'PUB_FUN'
Makes sure a walk from the checked-out head meets every commit since
<since>, so that git__history_reaches <since> prints true afterwards. A
full clone already does, and is left as it is. A shallow clone fetches older
commits from <remote>, origin by default, a step beyond every boundary at a
time, until no boundary is newer than the date. A remote that cannot be
asked leaves the clone as it was.

The older commits are fetched by count, not by date, because a fetch by
date can break the clone. It stops at the first merge after the date that
has a parent older than the date, and makes that merge the edge of the
clone. Every commit behind the merge is then missing from the walk, even
the ones newer than the date, and git fails every later fetch of older
commits, and --unshallow as well, with "error in object: unshallow".

  git__remotes__ensure_history_since 2026-10-07T23:52:13Z

Usage: git__remotes__ensure_history_since <since> [remote]
PUB_FUN
git__remotes__ensure_history_since() {
  if @is_false "$(git__is_shallow)"; then
    return 0
  fi
  __git__remotes__ensure_history_since__head="$(git__commit_of HEAD)" || return 0
  __git__remotes__fetch_history_until \
    "${2:-${GIT_REMOTE:-origin}}" \
    "$__git__remotes__ensure_history_since__head" \
    "$1"
}

: <<'FUN'
Fetches older commits of the head <ref> from <remote> into a shallow
clone, a step beyond every boundary at a time, until git__history_reaches
<since> prints true. Stops when a round brings no commit, or when the
remote cannot be asked, and leaves the clone as it stands then.

Usage: __git__remotes__fetch_history_until <remote> <ref> <since>
FUN
__git__remotes__fetch_history_until() {
  __git__remotes__fetch_history_until__remote="$1"
  __git__remotes__fetch_history_until__ref="$2"
  __git__remotes__fetch_history_until__since="$3"
  while @is_false "$(git__history_reaches "$__git__remotes__fetch_history_until__since")"; do
    __git__remotes__fetch_history_until__before="$(git__commit_count HEAD)"
    git__remotes__fetch_older_commits \
      "$__git__remotes__fetch_history_until__remote" \
      "$__git__remotes__fetch_history_until__ref" \
      "$__git__remotes__HISTORY_FETCH_STEP" \
      2>/dev/null \
      || return 0
    if [ "$(git__commit_count HEAD)" -eq "$__git__remotes__fetch_history_until__before" ]; then
      return 0
    fi
  done
}

: <<'PUB_FUN'
Fetches <count> older commits beyond every boundary of a shallow clone,
on the history of <ref>, from <remote>. Non-zero when the remote cannot
be asked. A full clone is left as it is.

  git__remotes__fetch_older_commits origin HEAD 20

Usage: git__remotes__fetch_older_commits <remote> <ref> <count>
PUB_FUN
git__remotes__fetch_older_commits() {
  git -C "$(__git__repo)" fetch --quiet --deepen="$3" "$1" "$2"
}

: <<'PUB_FUN'
Fetches the refs a three-dot diff between <base> and <head> needs, without
cloning the full history: both refs with their history back to <since>,
90 days ago by default, or SHELLOPS_DIFF_SINCE. When the base is still
missing after that, fetches it alone at depth one. Does nothing when the
clone already holds both.

  git__remotes__ensure_refs_for_diff 04ebe6f9... HEAD

Usage: git__remotes__ensure_refs_for_diff <base-ref> <head-ref> [since]
PUB_FUN
git__remotes__ensure_refs_for_diff() {
  __git__remotes__ensure_refs_for_diff__base="$1"
  __git__remotes__ensure_refs_for_diff__head="$2"
  __git__remotes__ensure_refs_for_diff__since="${3:-${SHELLOPS_DIFF_SINCE:-90.days.ago}}"
  __git__remotes__ensure_refs_for_diff__remote="${GIT_REMOTE:-origin}"

  git__ref_exists "$__git__remotes__ensure_refs_for_diff__base" && git__ref_exists "$__git__remotes__ensure_refs_for_diff__head" && return 0

  git__remotes__fetch_since \
    "$__git__remotes__ensure_refs_for_diff__remote" \
    "$__git__remotes__ensure_refs_for_diff__since" \
    "$__git__remotes__ensure_refs_for_diff__base" \
    "$__git__remotes__ensure_refs_for_diff__head" 2>/dev/null || true

  if ! git__ref_exists "$__git__remotes__ensure_refs_for_diff__base"; then
    git -C "$(__git__repo)" fetch --quiet --depth=1 \
      "$__git__remotes__ensure_refs_for_diff__remote" "$__git__remotes__ensure_refs_for_diff__base"
  fi
}

: <<'PUB_FUN'
Pushes <ref> to <remote> under the same name, so the remote holds what the
clone does; a remote already holding it is nothing to do. Non-zero when the
remote refuses it, as it does a ref moved past what the clone holds, or
cannot be reached.

  git__remotes__push_ref origin refs/notes/testing-trace

Usage: git__remotes__push_ref <remote> <ref>
PUB_FUN
git__remotes__push_ref() {
  git -C "$(__git__repo)" push -q "$1" "$2:$2"
}

: <<'PUB_FUN'
Pushes <commit> to <ref> on <remote> only while the remote still holds <ref>
at <expected>; an empty <expected> means the remote must not hold the ref at
all. Prints true when the push landed or the remote already held it there,
false when the remote refused it because the ref had moved, and fails when
the remote could not be asked, so a lost race and a lost network never read
the same.

  git__remotes__push_expecting origin refs/scheduler/lease/landing '' 9a02...  ->  true

args:
  $1  The remote
  $2  The ref on the remote
  $3  The commit the remote is expected to hold under it, or empty for none
  $4  The commit to push
PUB_FUN
git__remotes__push_expecting() {
  __git__remotes__push_expecting__status=0
  __git__remotes__push_expecting__report="$(git -C "$(__git__repo)" push \
    --porcelain \
    "--force-with-lease=$2:$3" \
    "$1" \
    "$4:$2" \
    2>&1
  )" || __git__remotes__push_expecting__status=$?

  __git__remotes__push_outcome \
    "$__git__remotes__push_expecting__status" \
    "$__git__remotes__push_expecting__report"
}

: <<'PUB_FUN'
Pushes every <refspec> to <remote> in one atomic push together with <ref>
held at <expected>, so the writes land only while the remote still holds
<ref> there and none of them lands otherwise: a tick's fence, its lease
pushed with its work. Prints true when they all landed, false when the
remote refused any of them, and fails when the remote could not be asked.

  git__remotes__push_atomic_expecting origin refs/scheduler/lease/landing 9a02... HEAD:refs/heads/main  ->  true

args:
  $1     The remote
  $2     The ref the push is conditioned on
  $3     The commit the remote is expected to hold under it
  $4...  The refspecs to push with it
PUB_FUN
git__remotes__push_atomic_expecting() {
  __git__remotes__push_atomic_expecting__remote="$1"
  __git__remotes__push_atomic_expecting__ref="$2"
  __git__remotes__push_atomic_expecting__expected="$3"
  shift 3

  __git__remotes__push_atomic_expecting__status=0
  __git__remotes__push_atomic_expecting__report="$(git -C "$(__git__repo)" push \
    --porcelain \
    --atomic \
    "--force-with-lease=$__git__remotes__push_atomic_expecting__ref:$__git__remotes__push_atomic_expecting__expected" \
    "$__git__remotes__push_atomic_expecting__remote" \
    "$__git__remotes__push_atomic_expecting__expected:$__git__remotes__push_atomic_expecting__ref" \
    "$@" \
    2>&1
  )" || __git__remotes__push_atomic_expecting__status=$?

  __git__remotes__push_outcome \
    "$__git__remotes__push_atomic_expecting__status" \
    "$__git__remotes__push_atomic_expecting__report"
}

: <<'FUN'
Prints true when a push's <status> is success, false when its porcelain
<report> shows the remote refusing a ref, and otherwise logs the report and
returns the status: the remote could not be asked.
FUN
__git__remotes__push_outcome() {
  if [ "$1" -eq 0 ]; then
    @true __git__remotes__push_outcome__out
    println "$__git__remotes__push_outcome__out"
    return 0
  fi
  if @is_true "$(__git__remotes__refused "$2")"; then
    @false __git__remotes__push_outcome__out
    println "$__git__remotes__push_outcome__out"
    return 0
  fi

  log "$2"
  return "$1"
}

: <<'FUN'
Prints true when a push's porcelain <report> shows the remote refusing a
ref, by its own check or a hook's, false otherwise.
FUN
__git__remotes__refused() {
  println "$1" | { @succeeds __git__remotes__refused__out grep -q '\[rejected\]\|\[remote rejected\]'; println "$__git__remotes__refused__out"; }
}

: <<'PUB_FUN'
Pushes every write in <writes> to <remote> in one atomic push, each ref
conditioned on the commit the caller last read there, so all of them land or
none does. Prints true when they landed, false when the remote refused any of
them, and fails when the remote could not be asked.

  git__remotes__push_leased origin '[{"ref":"refs/heads/feat","expected":"7d68","commit":"9a02"}]'
  ->  true

args:
  $1  The remote
  $2  The writes, a struct array of {ref, expected, commit}; an empty
      expected is the lease that the remote holds the ref at nothing yet
PUB_FUN
git__remotes__push_leased() {
  @map __git__remotes__push_leased__leases __git__remotes__lease_flag "$2"
  @map __git__remotes__push_leased__refspecs __git__remotes__lease_refspec "$2"
  @arr __git__remotes__push_leased__arr_1 "$1"
  @concat __git__remotes__push_leased__concat_2 "$__git__remotes__push_leased__leases" "$__git__remotes__push_leased__arr_1"
  @concat __git__remotes__push_leased__argv \
    "$__git__remotes__push_leased__concat_2" \
    "$__git__remotes__push_leased__refspecs"

  __git__remotes__push_leased__status=0
  __git__remotes__push_leased__report="$(@apply \
    git -C "$(__git__repo)" push --porcelain --atomic \
    "$__git__remotes__push_leased__argv" \
    2>&1
  )" || __git__remotes__push_leased__status=$?

  __git__remotes__push_outcome \
    "$__git__remotes__push_leased__status" \
    "$__git__remotes__push_leased__report"
}

: <<'FUN'
@map callback: the git flag holding the write <write>'s ref at the commit the
caller last read there.

  __git__remotes__lease_flag '{"ref":"refs/heads/feat","expected":"7d68"}'
    ->  --force-with-lease=refs/heads/feat:7d68
FUN
__git__remotes__lease_flag() {
  @get __git__remotes__lease_flag__get_3 "$1" '.ref'
  @get __git__remotes__lease_flag__get_4 "$1" '.expected' ''
  printf -- '--force-with-lease=%s:%s\n' "$__git__remotes__lease_flag__get_3" "$__git__remotes__lease_flag__get_4"
}

: <<'FUN'
@map callback: the refspec the write <write> pushes. The refspec carries no
force mark of its own, since one would override the lease beside it and let
the push land on a ref that moved.

  __git__remotes__lease_refspec '{"ref":"refs/heads/feat","commit":"9a02"}'  ->  9a02:refs/heads/feat
FUN
__git__remotes__lease_refspec() {
  @get __git__remotes__lease_refspec__get_5 "$1" '.commit'
  @get __git__remotes__lease_refspec__get_6 "$1" '.ref'
  printf '%s:%s\n' "$__git__remotes__lease_refspec__get_5" "$__git__remotes__lease_refspec__get_6"
}

: <<'PUB_FUN'
Fetches every tag <remote> holds into the clone, so a read of the tags here
reads the forge's. Non-zero when the remote cannot be reached.

  git__remotes__fetch_tags origin

Usage: git__remotes__fetch_tags <remote>
PUB_FUN
git__remotes__fetch_tags() {
  git -C "$(__git__repo)" fetch --quiet --tags "$1"
}
