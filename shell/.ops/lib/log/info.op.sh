#!/usr/bin/env bash

: <<'DOC'
Emit an info log line to stderr (stdout is the return channel).
DOC
@operation.info() {
  @in.string message

  @do() {
    printf 'INFO: %s\n' "$(@in message)" >&2
    @return
  }
}
