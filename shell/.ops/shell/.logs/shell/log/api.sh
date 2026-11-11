#!/bin/sh

: <<'MODULE'
Reporting to stderr from shell: one line per level, a prompt, and a banner.
Nothing here writes to stdout, which is every function's return channel. A
process loads this file as its vocabulary, so the names are bare: log,
info, warn, error, fatal, hint, prompt and banner.
MODULE

: <<'PUB_FUN'
Writes the message to stderr as a line, with no prefix.

args:
  $1  The message; empty when omitted
PUB_FUN
log() {  # public-name-check: allow -- loaded into every process as its vocabulary
  printf '%s\n' "${1-}" >&2
}

: <<'PUB_FUN'
Writes the message to stderr as a line prefixed "INFO: ".

args:
  $1  The message; empty when omitted
PUB_FUN
info() {  # public-name-check: allow -- loaded into every process as its vocabulary
  printf 'INFO: %s\n' "${1-}" >&2
}

: <<'PUB_FUN'
Writes the message to stderr as a line prefixed "WARN: ".

args:
  $1  The message; empty when omitted
PUB_FUN
warn() {  # public-name-check: allow -- loaded into every process as its vocabulary
  printf 'WARN: %s\n' "${1-}" >&2
}

: <<'PUB_FUN'
Writes the message to stderr as a line prefixed "ERROR: ".

args:
  $1  The message; empty when omitted
PUB_FUN
error() {  # public-name-check: allow -- loaded into every process as its vocabulary
  printf 'ERROR: %s\n' "${1-}" >&2
}

: <<'PUB_FUN'
Writes the message to stderr as a line prefixed "FATAL: ". Exiting is the
caller's decision.

args:
  $1  The message; empty when omitted
PUB_FUN
fatal() {  # public-name-check: allow -- loaded into every process as its vocabulary
  printf 'FATAL: %s\n' "${1-}" >&2
}

: <<'PUB_FUN'
Writes the message to stderr as a line prefixed "HINT: ".

args:
  $1  The message; empty when omitted
PUB_FUN
hint() {  # public-name-check: allow -- loaded into every process as its vocabulary
  printf 'HINT: %s\n' "${1-}" >&2
}

: <<'PUB_FUN'
Writes the message to stderr without a newline, so an answer can be typed
after it.

args:
  $1  The message; empty when omitted
PUB_FUN
prompt() {  # public-name-check: allow -- loaded into every process as its vocabulary
  printf '%s' "${1-}" >&2
}

: <<'PUB_FUN'
Writes the message to stderr centered between two rules of dashes. A rule is
at least 40 columns wide, and four wider than the message on each side when
the message needs more.

  banner hi   ->  ----------------------------------------
                                     hi
                  ----------------------------------------

args:
  $1  The message; empty when omitted
PUB_FUN
banner() {  # public-name-check: allow -- loaded into every process as its vocabulary
  __log__banner__message="${1-}"
  __log__banner__width=$((${#__log__banner__message} + 8))

  if [ "$__log__banner__width" -lt 40 ]; then
    __log__banner__width=40
  fi

  __log__rule "$__log__banner__width"
  __log__centered "$__log__banner__message" "$__log__banner__width"
  __log__rule "$__log__banner__width"
}

: <<'FUN'
Writes a line of dashes to stderr.

args:
  $1  The width, in columns
FUN
__log__rule() {
  printf '%*s\n' "$1" '' | tr ' ' '-' >&2
}

: <<'FUN'
Writes the message to stderr padded with spaces to sit in the middle of the
width, the odd column going to the right.

args:
  $1  The message
  $2  The width, in columns
FUN
__log__centered() {
  __log__centered__left=$((($2 - ${#1}) / 2))
  __log__centered__right=$(($2 - ${#1} - __log__centered__left))
  printf '%*s%s%*s\n' "$__log__centered__left" '' "$1" "$__log__centered__right" '' >&2
}
