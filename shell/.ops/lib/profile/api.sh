#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/kinds/api.sh" \
  "$SHELLOPS_DIR/lib/profile/_declaration.sh"

: <<'MODULE'
Profilers: what one command costs, measured by whichever profiler is named.

A profiler is a plugin of kind profile (lib/kinds/api.sh says how a kind
loads), a file named <name>.profile.op.sh defining @profile.<name>() with
these roles:

  @summary                 What the profiler measures, in one line. This is
                           what --list prints.
  @needs                   The programs the profiler runs, as a struct array.
                           ops profile refuses to run a profiler whose needs
                           are off the PATH, naming what to install.
  @run <trace> <command>   Runs the command under the profiler, writing what
                           it recorded to the file <trace>. Returns the
                           command's own status.
  @report <trace>          Renders the recording at <trace> to stdout.
  @totals <trace>          The measures the recording at <trace> comes to, as
                           a struct object of integers: what a ceiling in the
                           profiling declaration is held against, named by
                           these keys ({"forks":2506,"starts":684}).

Importing this module loads every profiler under lib/.
MODULE

__profile__ROLES="summary needs run report totals"
__profile__REQUIRED="summary run report totals"

: <<'PUB_FUN'
Loads and registers the profiler <name>, whose plugin file has been
imported. See kinds__load.
PUB_FUN
profile__load() {
  kinds__load profile "$1" "$__profile__ROLES" "$__profile__REQUIRED"
}

: <<'PUB_FUN'
Finds and loads every profiler under <root>. See kinds__scan.
PUB_FUN
profile__load_profilers() {
  kinds__scan profile "$1" "$__profile__ROLES" "$__profile__REQUIRED"
}

: <<'PUB_FUN'
Prints the names of every profiler, as a struct array, in load order.
PUB_FUN
profile__names() {
  kinds__names profile
}

: <<'PUB_FUN'
Prints the profiler <name>'s @summary: what it measures, in one line.
PUB_FUN
profile__summary() {
  kinds__call profile "$1" summary
}

: <<'PUB_FUN'
Runs the profiler <name>'s @run: records <command> to <trace>, returning the
command's own status.

Usage: profile__run <name> <trace> <command...>
PUB_FUN
profile__run() {
  __profile__run__name="$1"
  shift
  kinds__call profile "$__profile__run__name" run "$@"
}

: <<'PUB_FUN'
Runs the profiler <name>'s @report: renders the recording at <trace>.

Usage: profile__report <name> <trace>
PUB_FUN
profile__report() {
  kinds__call profile "$1" report "$2"
}

: <<'PUB_FUN'
Runs the profiler <name>'s @totals: the measures the recording at <trace>
comes to, as a struct object of integers keyed by measure.

  profile__totals forks trace.txt  ->  {"forks":2506,"starts":684}

Usage: profile__totals <name> <trace>
PUB_FUN
profile__totals() {
  kinds__call profile "$1" totals "$2"
}

: <<'PUB_FUN'
Prints one line per profiler: its name and what it measures. This is what
--list prints.
PUB_FUN
profile__describe() {
  @foreach __profile__describe "$(profile__names)"
}

: <<'FUN'
@foreach callback: prints the --list line for the wrapped profiler <name>.
FUN
__profile__describe() {
  @unwrap __profile__describe__name "$1"
  printf '%-12s %s\n' \
    "$__profile__describe__name" \
    "$(profile__summary "$__profile__describe__name")"
}

profile__load_profilers "$SHELLOPS_DIR/lib"
