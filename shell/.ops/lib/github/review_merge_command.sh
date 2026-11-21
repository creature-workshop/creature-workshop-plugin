#!/bin/sh

:<<'PUB_FUN'
Prints the CLI words that merge a review branch on GitHub, as this adaptor's
member of the review-merge-command contract.

Usage: github__review_merge_command   # -> gh pr merge
PUB_FUN
github__review_merge_command() {
  printf 'gh pr merge\n'
}
