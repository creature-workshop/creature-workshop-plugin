#!/bin/sh

import "$SHELLOPS_DIR/lib/rust/tools.sh"

: <<'MODULE'
Fuzzing a Rust project with cargo-fuzz on the nightly toolchain: checking that
the targets build, replaying a corpus, and exploring for a bounded time, each
run from the project directory and pinned to the host tuple nightly rustc
reports.

These are the commands a fuzz run is made of, beside the other frameworks
rather than under lib/rust, because what they drive is a test runner and not a
part of the Rust toolchain. The runner that attaches them to a suite is still
to come; until it does, action rust fuzz calls them directly.
MODULE

: <<'PUB_FUN'
Prints the target tuple the nightly rustc builds for, e.g.
x86_64-unknown-linux-gnu.

Every fuzz command passes it as --target. cargo-fuzz otherwise takes that
default from its own compile triple, and the only Linux binary it publishes is
a musl one, which cannot carry the sanitizer cargo-fuzz always injects.
PUB_FUN
testing__frameworks__fuzz__nightly_host_tuple() {
  rustc +nightly --print host-tuple
}

: <<'PUB_FUN'
Checks that a fuzz target builds, without running it.

args:
  $1  Project directory holding the fuzz package
  $2  Fuzz target name
PUB_FUN
testing__frameworks__fuzz__check() {
  __testing__frameworks__fuzz__check__project_dir="${1:?usage: testing__frameworks__fuzz__check <project-dir> <target>}"
  __testing__frameworks__fuzz__check__target="${2:?usage: testing__frameworks__fuzz__check <project-dir> <target>}"

  rust__assert_cargo_tool cargo-fuzz || return 1
  __testing__frameworks__fuzz__check__host="$(testing__frameworks__fuzz__nightly_host_tuple)"
  (
    cd "$__testing__frameworks__fuzz__check__project_dir" || exit
    cargo +nightly fuzz check \
      --target "$__testing__frameworks__fuzz__check__host" \
      "$__testing__frameworks__fuzz__check__target"
  )
}

: <<'PUB_FUN'
Replays the target's stored corpus once, exploring nothing new.

args:
  $1  Project directory holding the fuzz package
  $2  Fuzz target name
PUB_FUN
testing__frameworks__fuzz__replay() {
  __testing__frameworks__fuzz__replay__project_dir="${1:?usage: testing__frameworks__fuzz__replay <project-dir> <target>}"
  __testing__frameworks__fuzz__replay__target="${2:?usage: testing__frameworks__fuzz__replay <project-dir> <target>}"

  rust__assert_cargo_tool cargo-fuzz || return 1
  __testing__frameworks__fuzz__replay__host="$(testing__frameworks__fuzz__nightly_host_tuple)"
  (
    cd "$__testing__frameworks__fuzz__replay__project_dir" || exit
    cargo +nightly fuzz run \
      --target "$__testing__frameworks__fuzz__replay__host" \
      "$__testing__frameworks__fuzz__replay__target" \
      -- \
      -runs=0
  )
}

: <<'PUB_FUN'
Explores the target for a bounded number of seconds, keeping the corpus and
artifact directories it writes into.

args:
  $1  Project directory holding the fuzz package
  $2  Fuzz target name
  $3  Seconds to explore for
PUB_FUN
testing__frameworks__fuzz__explore() {
  __testing__frameworks__fuzz__explore__project_dir="${1:?usage: testing__frameworks__fuzz__explore <project-dir> <target> <seconds>}"
  __testing__frameworks__fuzz__explore__target="${2:?usage: testing__frameworks__fuzz__explore <project-dir> <target> <seconds>}"
  __testing__frameworks__fuzz__explore__seconds="${3:?usage: testing__frameworks__fuzz__explore <project-dir> <target> <seconds>}"

  __testing__frameworks__fuzz__validate_positive_integer "$__testing__frameworks__fuzz__explore__seconds" "seconds"
  rust__assert_cargo_tool cargo-fuzz || return 1
  __testing__frameworks__fuzz__explore__host="$(testing__frameworks__fuzz__nightly_host_tuple)"
  (
    cd "$__testing__frameworks__fuzz__explore__project_dir" || exit
    mkdir -p "fuzz/artifacts/$__testing__frameworks__fuzz__explore__target" "fuzz/corpus/$__testing__frameworks__fuzz__explore__target"
    cargo +nightly fuzz run \
      --target "$__testing__frameworks__fuzz__explore__host" \
      "$__testing__frameworks__fuzz__explore__target" \
      -- \
      -max_total_time="$__testing__frameworks__fuzz__explore__seconds"
  )
}

: <<'PUB_FUN'
Explores the target for a bounded number of minutes.

args:
  $1  Project directory holding the fuzz package
  $2  Fuzz target name
  $3  Minutes to explore for
PUB_FUN
testing__frameworks__fuzz__explore_minutes() {
  __testing__frameworks__fuzz__explore_minutes__project_dir="${1:?usage: testing__frameworks__fuzz__explore_minutes <project-dir> <target> <minutes>}"
  __testing__frameworks__fuzz__explore_minutes__target="${2:?usage: testing__frameworks__fuzz__explore_minutes <project-dir> <target> <minutes>}"
  __testing__frameworks__fuzz__explore_minutes__minutes="${3:?usage: testing__frameworks__fuzz__explore_minutes <project-dir> <target> <minutes>}"

  __testing__frameworks__fuzz__validate_positive_integer "$__testing__frameworks__fuzz__explore_minutes__minutes" "minutes"
  testing__frameworks__fuzz__explore "$__testing__frameworks__fuzz__explore_minutes__project_dir" "$__testing__frameworks__fuzz__explore_minutes__target" "$((__testing__frameworks__fuzz__explore_minutes__minutes * 60))"
}

: <<'PUB_FUN'
Explores for a bounded number of minutes and succeeds whatever the run exits
with, so a crash the run found still reaches the job that submits artifacts.

args:
  $1  Project directory holding the fuzz package
  $2  Fuzz target name
  $3  Minutes to explore for
PUB_FUN
testing__frameworks__fuzz__explore_minutes_nonblocking() {
  __testing__frameworks__fuzz__explore_minutes_nonblocking__project_dir="${1:?usage: testing__frameworks__fuzz__explore_minutes_nonblocking <project-dir> <target> <minutes>}"
  __testing__frameworks__fuzz__explore_minutes_nonblocking__target="${2:?usage: testing__frameworks__fuzz__explore_minutes_nonblocking <project-dir> <target> <minutes>}"
  __testing__frameworks__fuzz__explore_minutes_nonblocking__minutes="${3:?usage: testing__frameworks__fuzz__explore_minutes_nonblocking <project-dir> <target> <minutes>}"

  __testing__frameworks__fuzz__validate_positive_integer "$__testing__frameworks__fuzz__explore_minutes_nonblocking__minutes" "minutes"
  if ! testing__frameworks__fuzz__explore_minutes "$__testing__frameworks__fuzz__explore_minutes_nonblocking__project_dir" "$__testing__frameworks__fuzz__explore_minutes_nonblocking__target" "$__testing__frameworks__fuzz__explore_minutes_nonblocking__minutes"; then
    log "Fuzz exploration exited non-zero; continuing so crash submission can collect artifacts."
  fi
}

: <<'FUN'
Exits with an error unless the value is a positive integer.

args:
  $1  Value
  $2  Label naming the value in the error
FUN
__testing__frameworks__fuzz__validate_positive_integer() {
  __testing__frameworks__fuzz__validate_positive_integer__value="${1:?usage: __testing__frameworks__fuzz__validate_positive_integer <value> <label>}"
  __testing__frameworks__fuzz__validate_positive_integer__label="${2:?usage: __testing__frameworks__fuzz__validate_positive_integer <value> <label>}"

  case "$__testing__frameworks__fuzz__validate_positive_integer__value" in
    *[!0-9]*|'')
      error "Fuzz $__testing__frameworks__fuzz__validate_positive_integer__label must be a positive integer: $__testing__frameworks__fuzz__validate_positive_integer__value"
      exit 1
      ;;
  esac

  if [ "$__testing__frameworks__fuzz__validate_positive_integer__value" -eq 0 ]; then
    error "Fuzz $__testing__frameworks__fuzz__validate_positive_integer__label must be a positive integer: $__testing__frameworks__fuzz__validate_positive_integer__value"
    exit 1
  fi
}
