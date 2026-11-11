#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"
import "$SHELLOPS_DIR/lib/gitlab/review_merge_command.sh"
import "$SHELLOPS_DIR/lib/github/review_merge_command.sh"
import "$SHELLOPS_DIR/lib/forgejo/review_merge_command.sh"

:<<'FRAGMENT'
Classifying the forge operations a shell command performs.

Usage:
  import "$SHELLOPS_DIR/lib/forge/command_class.sh"

  forge__command_merges_review_branch "$command"
FRAGMENT

:<<'FUN'
Prints the review-merge command of every adaptor as a struct array of command
strings; a forge with no such CLI contributes no entry.
FUN
__forge__command_class__signatures() {
  @arr __forge__command_class__signatures__list
  for __forge__command_class__signatures__member in \
    gitlab__review_merge_command \
    github__review_merge_command \
    forgejo__review_merge_command
  do
    __forge__command_class__signatures__one="$("$__forge__command_class__signatures__member")"
    if @defined "$__forge__command_class__signatures__one"; then
      @wrap __forge__command_class__signatures__one "$__forge__command_class__signatures__one"
      @push __forge__command_class__signatures__list "$__forge__command_class__signatures__list" "$__forge__command_class__signatures__one"
    fi
  done
  println "$__forge__command_class__signatures__list"
}

:<<'PUB_FUN'
Prints true when the command merges a review branch through a forge CLI,
false otherwise.

Usage: forge__command_merges_review_branch "$command"
PUB_FUN
forge__command_merges_review_branch() {
  # The shell-aware lexer is shared with lib/git's classifiers so every
  # classifier reads commands the same way.
  __forge__command_merges_review_branch__list="$(__forge__command_class__signatures)"
  @join __forge__command_merges_review_branch__signatures "$__forge__command_merges_review_branch__list" ";"
  println "$1" \
    | {
      @succeeds __forge__command_merges_review_branch__out awk \
        -v "signatures=$__forge__command_merges_review_branch__signatures" \
        -f "$SHELLOPS_DIR/lib/git/shell_lex.awk" \
        -f "$SHELLOPS_DIR/lib/forge/merges_review_branch.awk"
      println "$__forge__command_merges_review_branch__out"
    }
}
