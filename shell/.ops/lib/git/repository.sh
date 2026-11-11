#!/bin/sh

import "$SHELLOPS_DIR/lib/kinds/api.sh"

# private-file-check: allow -- the repository kind's public surface, which a command that writes into a branch imports; its first callers are the branch site and the worktree plugin beside it
: <<'MODULE'
Repositories: the git repository a program reads refs from and moves refs
in, as a kind, so a site that is a branch (lib/git/branch.site.op.sh), a
certification that pushes a candidate and a command that writes files into
a branch say what they do in the repository's words and run no git
themselves. A repository is a struct whose `.kind` names the plugin and
whose other fields are what that plugin reads: a worktree repository names
the remote its refs are read from and pushed to, or none for the clone's
own refs, and what it knows about the forge it lives on
(lib/git/forge.sh).

A repository plugin is a plugin of kind repository (lib/kinds/api.sh says
how a kind loads), a file named <name>.repository.op.sh defining
@repository.<name>() with these roles:

  @summary                            The kind of repository in one line.
  @checkout <repository> <ref> <dir>  Makes the files <ref> points at present
                                      under <dir>, and prints a token naming
                                      the commit they came from, for @update
                                      to refuse a ref that moved meanwhile.
                                      A ref the repository does not have yet
                                      starts from a commit holding no files,
                                      and the token is empty.
  @head <repository> <dir>            Prints the commit the checkout under
                                      <dir> is at.
  @tip <repository> <ref>             Prints the commit <ref> points at,
                                      read fresh; nothing for a ref the
                                      repository does not have.
  @commit <repository> <dir> <message> <author> <email>
                                      Commits everything under <dir>, as it
                                      is now, as <author> with <email>,
                                      under <message>; commits nothing when
                                      nothing changed.
  @update <repository> <ref> <token> <commit>
                                      Points <ref> at <commit> when the ref is
                                      still at <token>; fails when it moved.
                                      An empty token is the lease that the
                                      ref does not exist yet. The role is
                                      named for git update-ref, since @push
                                      is a structs verb.
  @force <repository> <ref> <commit>  Points <ref> at <commit> whatever it
                                      held, creating it when it had none.
  @tag <repository> <tag>             Makes the tag <tag> the clone holds
                                      the repository's too. Fails when the
                                      repository holds it at another commit.
  @archive <repository> <dir> <out>   Writes the files of the commit the
                                      checkout under <dir> is at under <out>:
                                      the files and nothing of the
                                      repository.
  @remove <repository> <dir>          Deletes the checkout under <dir>.
  @prune <repository>                 Forgets the checkouts that are gone.

worktree is the first repository, lib/git/worktree.repository.op.sh: a checkout is
a linked worktree of the clone the program runs in, detached at the ref's
commit.

Importing this module loads every repository plugin under lib/.
MODULE

__git__repository__ROLES="summary checkout head tip commit update force tag archive remove prune"
__git__repository__REQUIRED="checkout head tip commit update force tag archive remove prune"

: <<'PUB_FUN'
Loads and registers the repository plugin <name>, whose file has been
imported. See kinds__load.
PUB_FUN
git__repository__load() {
  kinds__load repository "$1" "$__git__repository__ROLES" "$__git__repository__REQUIRED"
}

: <<'PUB_FUN'
Finds and loads every repository plugin under <root>. See kinds__scan.
PUB_FUN
git__repository__load_all() {
  kinds__scan repository "$1" "$__git__repository__ROLES" "$__git__repository__REQUIRED"
}

: <<'PUB_FUN'
Prints the names of every repository plugin, as a struct array, in load
order.
PUB_FUN
git__repository__names() {
  kinds__names repository
}

: <<'PUB_FUN'
Prints the repository plugin <name>'s @summary, one line.
PUB_FUN
git__repository__summary() {
  kinds__call repository "$1" summary
}

: <<'PUB_FUN'
Prints the kind of <repository>: the plugin its `.kind` names. Fails when
it names none, or one no plugin is registered under.

  git__repository__kind_of '{"kind": "worktree", "remote": "origin"}'  ->  worktree

Usage: git__repository__kind_of <repository>
PUB_FUN
git__repository__kind_of() {
  @get __git__repository__kind_of__kind "$1" '.kind' ''

  if ! @defined "$__git__repository__kind_of__kind"; then
    error "repository: a repository names its kind, and this one does not: $1"
    return 1
  fi

  kinds__require_known repository "$__git__repository__kind_of__kind" || return 1
  println "$__git__repository__kind_of__kind"
}

: <<'FUN'
Calls the role <role> of the plugin <repository> names, with the repository
and the arguments after them. Fails as git__repository__kind_of does.

Usage: __git__repository__call <repository> <role> [args...]
FUN
__git__repository__call() {
  __git__repository__call__kind="$(git__repository__kind_of "$1")" || return 1
  __git__repository__call__repository="$1"
  __git__repository__call__role="$2"
  shift 2

  kinds__call repository "$__git__repository__call__kind" "$__git__repository__call__role" "$__git__repository__call__repository" "$@"
}

: <<'PUB_FUN'
Makes the files <ref> points at in <repository> present under <dir>, and
prints the token @update takes. See @checkout.

Usage: git__repository__checkout <repository> <ref> <dir>
PUB_FUN
git__repository__checkout() {
  __git__repository__call "$1" checkout "$2" "$3"
}

: <<'PUB_FUN'
Prints the commit the checkout <dir> of <repository> is at. See @head.

Usage: git__repository__head <repository> <dir>
PUB_FUN
git__repository__head() {
  __git__repository__call "$1" head "$2"
}

: <<'PUB_FUN'
Prints the commit <ref> points at in <repository>, or nothing. See @tip.

Usage: git__repository__tip <repository> <ref>
PUB_FUN
git__repository__tip() {
  __git__repository__call "$1" tip "$2"
}

: <<'PUB_FUN'
Commits everything under the checkout <dir> of <repository> as <author>
with <email>, under <message>. See @commit.

Usage: git__repository__commit <repository> <dir> <message> <author> <email>
PUB_FUN
git__repository__commit() {
  __git__repository__call "$1" commit "$2" "$3" "$4" "$5"
}

: <<'PUB_FUN'
Points <ref> in <repository> at <commit> under a lease on <token>. See
@update.

Usage: git__repository__update <repository> <ref> <token> <commit>
PUB_FUN
git__repository__update() {
  __git__repository__call "$1" update "$2" "$3" "$4"
}

: <<'PUB_FUN'
Points <ref> in <repository> at <commit> whatever it held. See @force.

Usage: git__repository__force <repository> <ref> <commit>
PUB_FUN
git__repository__force() {
  __git__repository__call "$1" force "$2" "$3"
}

: <<'PUB_FUN'
Makes the tag <tag> the repository's too. See @tag.

Usage: git__repository__tag <repository> <tag>
PUB_FUN
git__repository__tag() {
  __git__repository__call "$1" tag "$2"
}

: <<'PUB_FUN'
Writes the files of the commit the checkout <dir> of <repository> is at
under <out>. See @archive.

Usage: git__repository__archive <repository> <dir> <out>
PUB_FUN
git__repository__archive() {
  __git__repository__call "$1" archive "$2" "$3"
}

: <<'PUB_FUN'
Deletes the checkout <dir> of <repository>. See @remove.

Usage: git__repository__remove <repository> <dir>
PUB_FUN
git__repository__remove() {
  __git__repository__call "$1" remove "$2"
}

: <<'PUB_FUN'
Forgets the checkouts of <repository> that are gone. See @prune.

Usage: git__repository__prune <repository>
PUB_FUN
git__repository__prune() {
  __git__repository__call "$1" prune
}

git__repository__load_all "$SHELLOPS_DIR/lib"
