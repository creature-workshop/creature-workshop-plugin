#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/ecosystems/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/git/commits.sh" \
  "$SHELLOPS_DIR/lib/git/remotes.sh" \
  "$SHELLOPS_DIR/lib/git/tags.sh" \
  "$SHELLOPS_DIR/lib/releases/files.sh" \
  "$SHELLOPS_DIR/lib/releases/record/api.sh"

: <<'MODULE'
The record commit. When an attempt earns a tier for a version, it records
the version in a commit of its own, off the trunk. The commit's parent is
the trunk commit that a merge request merged as (ADR 000044), and its
message ends with a trailer that names the version. The trailer is how a
reader tells a record from the trunk commit under it. The attempt writes
one record per tier it earns (releases__record__write) and publishes the
record with its tag in one atomic push (releases__record__publish). So the
trunk never carries a record, and a tier is earned exactly when its tag
exists. The record's fields in the lock, latest and stable, are
lib/releases/record/api.sh.

As a value, a record is the struct {name, candidate, commit}: name is what
the tag is called, candidate is the trunk commit the record sits on, and
commit is the record's own commit.
MODULE

# CONST: The name of the trailer a record's commit message ends with. Its value is the version.
__releases__record__TRAILER="Release-Record"

: <<'PUB_FUN'
Prints the trailer line for a record of <version>: the last line of the
record commit's message.

  releases__record__trailer 1.2.0-rc.1  ->  Release-Record: 1.2.0-rc.1

Usage: releases__record__trailer <version>
PUB_FUN
releases__record__trailer() {
  printf '%s: %s\n' "$__releases__record__TRAILER" "$1"
}

: <<'PUB_FUN'
Prints the version that the commit at <ref> records, read from its
trailer. Prints nothing when the commit is not a record, that is, when its
message has no such trailer. Fails when <ref> resolves to no commit.

  releases__record__at main  ->  1.2.0-rc.1
  releases__record__at main  ->  (nothing, for a merge at the tip)

Usage: releases__record__at <ref>
PUB_FUN
releases__record__at() {
  git__commits__trailer "$1" "$__releases__record__TRAILER"
}

: <<'PUB_FUN'
Prints the commit message for a record of <name>: the release subject
line, a blank line, then the trailer.

  releases__record__message 1.2.0-rc.1  ->  chore: release 1.2.0-rc.1
                                            <blank line>
                                            Release-Record: 1.2.0-rc.1

Usage: releases__record__message <name>
PUB_FUN
releases__record__message() {
  printf 'chore: release %s\n\n%s\n' "$1" "$(releases__record__trailer "$1")"
}

: <<'PUB_FUN'
Writes the record of <name> for the candidate <candidate>, and prints the
record as the struct {name, candidate, commit}. The record is a commit
whose parent is the candidate. Its tree is the candidate's tree with the
version files (releases__release_files) set to <name>, and its message
ends with the trailer. The commit is tagged <name> in this clone. The
record is built in a linked worktree of its own, which is removed
afterwards, so the checkout keeps its branch, index and working tree.
Nothing is pushed; releases__record__publish does that. Fails when the
candidate resolves to no commit, when a version file cannot be written, or
when this clone already has a tag named <name>.

  releases__record__write 9a02... 0.67.0-6.rc
    ->  {"name": "0.67.0-6.rc", "candidate": "9a02...", "commit": "3f1c..."}

Output:
  The record is all this prints; an installer's output among the build's
  steps goes to stderr.

args:
  $1  The candidate's commit
  $2  The record's name, the tag's name: a version and its tier with the
      counter, or the version alone at stable
PUB_FUN
releases__record__write() {
  __releases__record__write__candidate="$(git__commit_of "$1")" || return 1
  __releases__record__write__dir="$(mktemp -d)/record"
  git__worktree_checkout "$__releases__record__write__dir" "$__releases__record__write__candidate" || return 1
  if ! __releases__record__build "$__releases__record__write__dir" "$2" >&2; then
    git__worktree_remove "$__releases__record__write__dir"
    return 1
  fi
  __releases__record__write__sha="$(git__worktree_head "$__releases__record__write__dir")"
  git__worktree_remove "$__releases__record__write__dir"
  git__tag_annotate "$2" "$__releases__record__write__sha" || return 1
  @obj __releases__record__write__out \
    '.name' "$2" \
    '.candidate' "$__releases__record__write__candidate" \
    '.commit' "$__releases__record__write__sha"
  println "$__releases__record__write__out"
}

: <<'FUN'
Builds the record commit for <name> in the worktree at <dir>, which is
checked out at the candidate. Three steps: sets latest to <name> in the
lock there, and stable too when <name> is a release; writes <name> into
each ecosystem's version file; and commits the lock and those files with
the record's message. Nothing else is in the commit.
FUN
__releases__record__build() {
  releases__record__set_version "$2" "$1" || return 1
  __releases__record__sync_ecosystems "$1" "$2" || return 1
  git -C "$1" commit -q -m "$(releases__record__message "$2")"
}

: <<'FUN'
Writes <name> into each ecosystem's version file under <dir>, such as a
Cargo.toml or a package.json, and stages every version file there, the
lock included, so that the record commit takes them all. An ecosystem
finds the project it writes to through the PROJ variable and nothing
else. So this runs in a subshell where PROJ is <dir>, and the caller's
PROJ is left as it was.
FUN
__releases__record__sync_ecosystems() {
  (
    PROJ="$1"
    export PROJ
    ecosystems__sync_version "$2" || exit 1
    __releases__record__sync_ecosystems__files="$(releases__release_files)" || exit 1
    @apply git -C "$1" add -- "$__releases__record__sync_ecosystems__files"
  )
}

: <<'PUB_FUN'
Publishes <record> to <remote>. Pushes the record's tag, which is the
only ref that reaches the record's commit, together with the <writes>
given, in one atomic push. Each write is held to the commit the caller
last read at its ref. The remote refuses the whole push when it already
has the tag or when any write's ref has moved. Prints true when everything
landed, and false when the remote refused. Fails when the remote could not
be asked, so that a name another attempt took and a lost network never
look the same. An attempt passes its top tier's branch, certified, as one
of the writes, so a tier is never earned without the branch following
(ADR.4@global).

  releases__record__publish origin "$record"  ->  true
  releases__record__publish origin "$record" '[{"ref":"refs/heads/certified","expected":"7d68","commit":"3f1c"}]'  ->  true

args:
  $1  The remote
  $2  The record ({name, candidate, commit}), its tag held by this clone
  $3  Further writes to land with the tag, a struct array of {ref, expected,
      commit} as git__remotes__push_leased takes them; none when omitted
PUB_FUN
releases__record__publish() {
  @get __releases__record__publish__get_1 "$2" '.name'
  __releases__record__publish__ref="refs/tags/$__releases__record__publish__get_1"
  @obj __releases__record__publish__tag \
    '.ref' "$__releases__record__publish__ref" \
    '.expected' '' \
    '.commit' "$__releases__record__publish__ref"
  @arr __releases__record__publish__arr_2 "$__releases__record__publish__tag"
  @arr __releases__record__publish__arr_3
  @concat __releases__record__publish__writes \
    "$__releases__record__publish__arr_2" \
    "${3:-$__releases__record__publish__arr_3}"
  git__remotes__push_leased "$1" "$__releases__record__publish__writes"
}
