#!/bin/sh

:<<'PUB_FUN'
Prints the CLI words that merge a review branch on GitLab, as this adaptor's
member of the review-merge-command contract.

Usage: gitlab__review_merge_command   # -> glab mr merge
PUB_FUN
gitlab__review_merge_command() {
  printf 'glab mr merge\n'
}
