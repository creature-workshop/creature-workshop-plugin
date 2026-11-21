#!/bin/sh

: <<'MODULE'
The transcript driver of a golden fileset. It reads a calls file and
writes one block per call: a "## <call>" line, the answer below it, and
"!! <status> <message>" when the call fails. When the message is empty,
that line is "!! <status> " and keeps the space after the status.

A caller sources this file and gives golden__transcribe the name of a
hook function. The hook receives one call line, runs it in whatever way
the library under test needs, and leaves the answer in GOLDEN_ANSWER and
the status in GOLDEN_STATUS. Both are reset before each call, to '' and
0. What the hook writes to stderr is the message printed after "!!".

A blank line and a line that starts with # are skipped. A line written
"as <name> <call>" runs <call> and keeps its answer in the register
<name>. golden__register_of reads a register, so a hook can let a later
call refer to an earlier answer.

The driver runs in strict POSIX sh, so that a consumer can check one
fileset under every shell it names.
MODULE

: <<'PUB_FUN'
Writes the transcript of a calls file through the hook, one block per
call. Sets GOLDEN_CALLS_DIR to the directory of the calls file, which
golden__file_of reads, and GOLDEN_STDERR to the scratch file that the
hook's stderr goes to. The scratch file is removed when the transcript
ends.

The calls file is read on a descriptor of its own, so the hook's stdin is
the caller's, and a call that reads stdin reads what the caller gave.

args:
  $1  The hook: a function that takes one call line
  $2  The calls file
PUB_FUN
golden__transcribe() {
  __golden__transcribe__hook="$1"
  GOLDEN_CALLS_DIR="$(__golden__directory_of "$2")"
  GOLDEN_STDERR="$(mktemp "${TMPDIR:-/tmp}/golden-transcript.XXXXXX")"

  while IFS= read -r __golden__transcribe__line <&3; do
    case "$__golden__transcribe__line" in
      '' | '#'*) continue ;;
    esac
    __golden__transcribe_call "$__golden__transcribe__hook" "$__golden__transcribe__line"
  done 3< "$2"

  rm -f "$GOLDEN_STDERR"
}

: <<'PUB_FUN'
Runs a command and keeps its exit status in GOLDEN_STATUS when it fails.
A hook runs each command of a call through this, so that a failure is
reported in the transcript and the transcript goes on.

args:
  $@  The command and its arguments
PUB_FUN
golden__capture() {
  "$@" || GOLDEN_STATUS=$?
}

: <<'PUB_FUN'
Prints the text after the first word of a line and one space, or nothing
when the line is one word.

  golden__argument_of "upper hello world"  ->  "hello world"
PUB_FUN
golden__argument_of() {
  __golden__argument_of__rest="${1#"${1%% *}"}"
  printf '%s' "${__golden__argument_of__rest# }"
}

: <<'PUB_FUN'
Prints the answer kept in a register by an "as <name> <call>" line.

args:
  $1  The register's name, as written after "as"
PUB_FUN
golden__register_of() {
  eval "printf '%s' \"\$GOLDEN_REGISTER_$1\""
}

: <<'PUB_FUN'
Prints the path of a file that a call names: as given when absolute, and
beside the calls file otherwise.

  golden__file_of "greeting/greeting.txt"  ->  "<calls dir>/greeting/greeting.txt"
PUB_FUN
golden__file_of() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *) printf '%s/%s' "$GOLDEN_CALLS_DIR" "$1" ;;
  esac
}

: <<'PUB_FUN'
Prints text written with printf escapes as the characters it means, so
that a call can write a newline or a control character.
PUB_FUN
golden__unescape() {
  printf '%b' "$1"
}

: <<'FUN'
Prints the directory part of a path, or . when the path has none.
FUN
__golden__directory_of() {
  case "$1" in
    */*) printf '%s' "${1%/*}" ;;
    *) printf '.' ;;
  esac
}

: <<'FUN'
Writes one block: the call's line, then what the hook answered or why
the call failed. A line "as <name> <call>" also keeps the answer in the
register <name>.

args:
  $1  The hook
  $2  The call line
FUN
__golden__transcribe_call() {
  GOLDEN_ANSWER=''
  GOLDEN_STATUS=0
  printf '## %s\n' "$2"

  case "${2%% *}" in
    as) __golden__keep_answer "$1" "$(golden__argument_of "$2")" ;;
    *) __golden__run_hook "$1" "$2" ;;
  esac

  __golden__report_answer
}

: <<'FUN'
Runs the call after the register's name through the hook, and keeps the
answer under that name.

args:
  $1  The hook
  $2  The register's name, then the call
FUN
__golden__keep_answer() {
  __golden__run_hook "$1" "$(golden__argument_of "$2")"
  eval "GOLDEN_REGISTER_${2%% *}=\$GOLDEN_ANSWER"
}

: <<'FUN'
Runs the hook on one call line, with its stderr kept in the scratch file.

args:
  $1  The hook
  $2  The call line
FUN
__golden__run_hook() {
  "$1" "$2" 2>"$GOLDEN_STDERR"
}

: <<'FUN'
Prints the answer, and after a failure its status and the message the
hook wrote to stderr.
FUN
__golden__report_answer() {
  if [ "$GOLDEN_STATUS" -eq 0 ]; then
    printf '%s\n' "$GOLDEN_ANSWER"
    return
  fi

  if [ -n "$GOLDEN_ANSWER" ]; then
    printf '%s\n' "$GOLDEN_ANSWER"
  fi
  printf '!! %s %s\n' "$GOLDEN_STATUS" "$(cat "$GOLDEN_STDERR")"
}
