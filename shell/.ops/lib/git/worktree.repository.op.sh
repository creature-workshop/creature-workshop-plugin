#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/git/_worktree_repository.sh"

:<<'DOC'
The worktree repository: a ref checked out as a linked worktree of the clone
the program runs in. _worktree_repository.sh beside this file says how; see
lib/git/repository.sh for what the roles mean.
DOC
@repository.worktree() {
  @summary() {
    println "A linked worktree of this clone, read from and pushed to the remote the repository names."
  }

  @checkout() {
    __git__worktree_repository__checkout "$1" "$2" "$3"
  }

  @head() {
    git__worktree_head "$2"
  }

  @tip() {
    __git__worktree_repository__tip "$1" "$2"
  }

  @commit() {
    __git__worktree_repository__commit "$2" "$3" "$4" "$5"
  }

  @update() {
    __git__worktree_repository__update "$1" "$2" "$3" "$4"
  }

  @force() {
    __git__worktree_repository__force "$1" "$2" "$3"
  }

  @tag() {
    __git__worktree_repository__tag "$1" "$2"
  }

  @archive() {
    __git__worktree_repository__archive "$2" "$3"
  }

  @remove() {
    rm -rf "$2"
  }

  @prune() {
    git__worktree_prune
  }
}
