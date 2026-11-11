#!/bin/sh

import "$SHELLOPS_DIR/lib/http/api.sh"

:<<'FRAGMENT'
The models a claude-cli run may name, asked of Anthropic. The Claude Code CLI
has no command that says what an account may use, so the adaptor asks the
account's own provider instead of carrying a list beside the plugin, which
would be wrong on the day a model ships and wrong again on the day one
retires.

The key travels in the header Anthropic reads it from, and the version of the
API this speaks travels beside it, because Anthropic dates its API rather than
putting the version in the path. The key is read out of the run options the way
every other role reads it, through the context options.sh names, which the
adaptor's plugin imports beside this file.

API reference: https://docs.anthropic.com/en/api/models-list
FRAGMENT

__agents__claude_cli__models__BASE="${ANTHROPIC_API_BASE:-https://api.anthropic.com}"
__agents__claude_cli__models__PATH="/v1/models"
__agents__claude_cli__models__API_VERSION="2023-06-01"

:<<'FUN'
Prints the URL the models an account may use are listed at.

  __agents__claude_cli__models__url  ->  https://api.anthropic.com/v1/models
FUN
__agents__claude_cli__models__url() {
  printf '%s%s\n' "$__agents__claude_cli__models__BASE" "$__agents__claude_cli__models__PATH"
}

:<<'FUN'
Prints the request options a read of the models takes: the key the run options
$1 carry and the API version this speaks, as the headers Anthropic reads them
from. Fails, naming ANTHROPIC_API_KEY, when the options carry no key.
FUN
__agents__claude_cli__models__request_opts() {
  __agents__claude_cli__models__request_opts__key="$(agents__headless__require_key "$__agents__claude_cli__CONTEXT" "$1")" || return 1
  @obj __agents__claude_cli__models__request_opts__obj_1 \
    '."x-api-key"'         "$__agents__claude_cli__models__request_opts__key" \
    '."anthropic-version"' "$__agents__claude_cli__models__API_VERSION"
  @obj __agents__claude_cli__models__request_opts__out '.headers' "$__agents__claude_cli__models__request_opts__obj_1"
  println "$__agents__claude_cli__models__request_opts__out"
}

:<<'FUN'
Prints the models the run options $1's account may use, as an array of id,
newest first; empty when the account lists none. Fails when the options carry
no key or Anthropic does not answer.

  __agents__claude_cli__models__list "$options"  ->  [{"id":"claude-opus-4-5-20260101"}]
FUN
__agents__claude_cli__models__list() {
  __agents__claude_cli__models__list__opts="$(__agents__claude_cli__models__request_opts "$1")" || return 1
  __agents__claude_cli__models__list__body="$(http__get "$(__agents__claude_cli__models__url)" "$__agents__claude_cli__models__list__opts")" || return 1
  @arr __agents__claude_cli__models__list__none
  @get __agents__claude_cli__models__list__listed "$__agents__claude_cli__models__list__body" '.data' "$__agents__claude_cli__models__list__none"
  @project __agents__claude_cli__models__list__out "$__agents__claude_cli__models__list__listed" '{id}'
  println "$__agents__claude_cli__models__list__out"
}
