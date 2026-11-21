#!/bin/sh

:<<'PUB_FUN'
Prints the CLI words that merge a review branch on Forgejo: nothing, since no
such CLI serves this workspace, and emptiness is the answer rather than a
failure.

Usage: forgejo__review_merge_command   # ->
PUB_FUN
forgejo__review_merge_command() {
  :
}
