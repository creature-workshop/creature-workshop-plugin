#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/testing/adapter.sh" \
  "$SHELLOPS_DIR/lib/testing/resolver.sh" \
  "$SHELLOPS_DIR/lib/testing/trace/_tracer.sh" \
  "$SHELLOPS_DIR/lib/testing/trace/_observation.sh" \
  "$SHELLOPS_DIR/lib/testing/trace/location.sh" \
  "$SHELLOPS_DIR/lib/time/api.sh"

: <<'FRAGMENT'
The trace map: every test of every file-keyed suite run one file at a time
under the tracer, and what each one touched, as one struct keyed by the
commit it ran at. Each test file runs in a fresh process the caller names
(ops test suite <name> <file>, for the CLI), and only the runner it hands
the file to counts: the process that starts a program with the file among
its arguments, and what that starts. What the caller loads and reads to get
there, its config and schemas among them, is not the test's dependency.

The map is kept after every file, so a run cut short leaves the map it
had; and a run starts from the map it is given, carrying forward every
entry whose files are unchanged since the commit it was traced at, so the
next run traces only the rest. A run given a budget stops between two
files once it is spent, so it ends on its own and not by a timeout.

  testing__trace__map   the map for a set of suites, every test run traced
FRAGMENT

: <<'CONST'
How one test file's run under the tracer ended: the words an entry's status
carries, the schema's status set.
CONST
@enum __testing__trace__map__STATUS PASSED FAILED

: <<'CONST'
The program that plans a run from the prior map: which entries carry
forward, and which files are left to trace.
CONST
__testing__trace__map__PLAN="$SHELLOPS_DIR/lib/testing/trace/plan.awk"

: <<'PUB_FUN'
Records the map for the effective <suites>: every test file of every
traceable suite run on its own under the tracer by the given command,
except the files <prior> holds an entry for that still holds: one naming
the commit it was traced at, none of whose files, the test file among
them, differ between that commit and this run's. A run recording no commit
carries nothing forward. The map is kept, as file and note, after every
file traced, so a run cut short leaves the map it had, and a run on a
budget stops between two files once it is spent. Fails when the host
cannot trace; stops, keeping what it has, when a test's run ends by a
signal, since what that test read is incomplete. A failing test still
records what it read, with its status.

  testing__trace__map "$suites" "$prior" "" "$SHELLOPS_DIR/cli/test" suite
  ->  {"commit": "9fa43442...", "recorded_at": "2026-09-18T20:00:00Z",
       "tracer": "strace", "suites": {"unit": {"runner": "bats", "tests": {
         "test/string.api.bats": {"commit": "9fa43442...", "status": "passed",
                                  "reads": [...], ...}}}}}

args:
  $1  The effective suites (from testing__effective_suites)
  $2  The map to start from (from testing__trace__latest_map), or empty
  $3  The budget, in whole seconds, or empty for none
  $@  The command that runs one file of a suite, given the suite name and
      the file as its last two arguments
PUB_FUN
testing__trace__map() {
  __testing__trace__map__all="$1"
  __testing__trace__map__prior="${2:-}"
  __testing__trace__map__budget="${3:-}"
  shift 3 2>/dev/null || shift $#
  if @is_zero "$#"; then
    error "testing/trace: no command to run a test file with."
    return 1
  fi
  __testing__trace__map__deadline="$(__testing__trace__map__deadline "$__testing__trace__map__budget")" || return 1
  if @is_false "$(__testing__trace__permitted)"; then
    error "testing/trace: this host cannot trace: strace is missing, or ptrace is not permitted here."
    return 1
  fi

  __testing__trace__map__at="$(__testing__trace__map__commit)"
  @entries __testing__trace__map__entries_1 "$__testing__trace__map__all"
  @obj __testing__trace__map__obj_2
  @reduce __testing__trace__map__traceable __testing__trace__map__suite \
    "$__testing__trace__map__entries_1" \
    "$__testing__trace__map__obj_2" || return 1
  __testing__trace__map__plan="$(__testing__trace__map__plan \
    "$__testing__trace__map__traceable" \
    "$__testing__trace__map__prior" \
    "$__testing__trace__map__at"
  )" || return 1
  @get __testing__trace__map__get_3 "$__testing__trace__map__plan" '.carried'
  @get __testing__trace__map__get_4 "$__testing__trace__map__plan" '.work'
  @len __testing__trace__map__len_5 "$__testing__trace__map__get_4"
  log "testing/trace: $__testing__trace__map__get_3 entry(ies) carried forward, $__testing__trace__map__len_5 file(s) to trace."

  @wrap __testing__trace__map__wrap_6 "$(time__utc_timestamp)"
  @wrap __testing__trace__map__wrap_7 strace
  @get __testing__trace__map__get_8 "$__testing__trace__map__plan" '.suites'
  @obj __testing__trace__map__start \
    '.commit' "$__testing__trace__map__at" \
    '.recorded_at' "$__testing__trace__map__wrap_6" \
    '.tracer' "$__testing__trace__map__wrap_7" \
    '.suites' "$__testing__trace__map__get_8"
  @get __testing__trace__map__get_9 "$__testing__trace__map__plan" '.work'
  @arr __testing__trace__map__arr_10 "$@"
  __testing__trace__map__trace_each \
    "$__testing__trace__map__start" \
    "$__testing__trace__map__get_9" \
    "$__testing__trace__map__arr_10" \
    "$__testing__trace__map__deadline"
}

: <<'FUN'
The commit the map is recorded at, as a struct string, or null outside CI.
FUN
__testing__trace__map__commit() {
  if @defined "${CI_COMMIT_SHA:-}"; then
    @wrap __testing__trace__map__commit__out "$CI_COMMIT_SHA"
    println "$__testing__trace__map__commit__out"
  else
    @null __testing__trace__map__commit__out
    println "$__testing__trace__map__commit__out"
  fi
}

: <<'FUN'
Prints the deadline a budget sets, as whole seconds since the epoch, from
now; nothing for no budget. Fails, saying so, for a budget that is not a
whole number of seconds, so a mistyped budget never reads as none.

args:
  $1  The budget, in whole seconds, or empty
FUN
__testing__trace__map__deadline() {
  if ! @defined "$1"; then
    return 0
  fi
  if ! [ "$1" -ge 0 ] 2>/dev/null; then
    error "testing/trace: the budget is a whole number of seconds, not '$1'."
    return 1
  fi
  __testing__trace__map__deadline__now="$(time__epoch_seconds)"
  println "$((__testing__trace__map__deadline__now + $1))"
}

: <<'FUN'
@reduce callback: one suite's runner and test files added to the traceable
suites under its name, or the suites unchanged for a suite the trace
cannot key.

args:
  $1  The traceable suites so far ({<name>: {runner, files}})
  $2  The suite entry ({key, value})
FUN
__testing__trace__map__suite() {
  @let "$2" __testing__trace__map__suite__ key value
  __testing__trace__map__suite__name="$__testing__trace__map__suite__key"
  __testing__trace__map__suite__cfg="$__testing__trace__map__suite__value"
  @unlet __testing__trace__map__suite__ key value
  @get __testing__trace__map__suite__runner \
    "$__testing__trace__map__suite__cfg" \
    '.runner' \
    "$__testing__trace__map__suite__name"

  __testing__trace__map__suite__traceable="$(__testing__trace__map__traceable \
    "$__testing__trace__map__suite__runner" \
    "$__testing__trace__map__suite__cfg"
  )"
  if @is_false "$__testing__trace__map__suite__traceable"; then
    log "testing/trace: suite '$__testing__trace__map__suite__name' is not keyed by file path; not traced."
    println "$1"
    return 0
  fi

  __testing__trace__map__suite__files="$(__testing__trace__map__files \
    "$__testing__trace__map__suite__cfg"
  )" || return 1
  @len __testing__trace__map__suite__len_11 "$__testing__trace__map__suite__files"
  log "testing/trace: suite '$__testing__trace__map__suite__name' via runner '$__testing__trace__map__suite__runner' has $__testing__trace__map__suite__len_11 file(s)."
  @wrap __testing__trace__map__suite__wrap_12 "$__testing__trace__map__suite__runner"
  @obj __testing__trace__map__suite__obj_13 \
    '.runner' "$__testing__trace__map__suite__wrap_12" \
    '.files' "$__testing__trace__map__suite__files"
  @set __testing__trace__map__suite__out "$1" ".\"$__testing__trace__map__suite__name\"" "$__testing__trace__map__suite__obj_13"
  println "$__testing__trace__map__suite__out"
}

: <<'FUN'
Prints true when a suite can be traced one file at a time: its runner is
registered and joins escapes by file path, and the suite has a root to
enumerate its files under.

args:
  $1  The runner
  $2  The effective suite config
FUN
__testing__trace__map__traceable() {
  if @is_false "$(testing__adapter_registered "$1")"; then
    @false __testing__trace__map__traceable__out
    println "$__testing__trace__map__traceable__out"
    return 0
  fi
  if [ "$(testing__runner_escape_key "$1" "$2")" != file-path ]; then
    @false __testing__trace__map__traceable__out
    println "$__testing__trace__map__traceable__out"
    return 0
  fi
  @get __testing__trace__map__traceable__get_14 "$2" '.root' ''
  @succeeds __testing__trace__map__traceable__out @defined "$__testing__trace__map__traceable__get_14"
  println "$__testing__trace__map__traceable__out"
}

: <<'FUN'
The test files a suite has in full, as a struct array of $PROJ-relative
paths: the tracked files under its root that its patterns keep.

args:
  $1  The effective suite config
FUN
__testing__trace__map__files() {
  @get __testing__trace__map__files__get_15 "$1" '.root'
  @arr __testing__trace__map__files__arr_16 "$__testing__trace__map__files__get_15"
  testing__glob_files \
    "$__testing__trace__map__files__arr_16" \
    "$(testing__suite_patterns "$1" '.glob')" \
    "$(testing__suite_patterns "$1" '.exclude')"
}

: <<'FUN'
Prints the plan a run starts from, {suites, work, carried}: the map's
suites with the prior's carried entries in place, the {suite, file} pairs
left to trace in sorted order, and how many entries were carried. See
plan.awk for what carries.

args:
  $1  The traceable suites ({<name>: {runner, files}})
  $2  The prior map, or empty
  $3  The commit this run records (a struct string, or null)
FUN
__testing__trace__map__plan() {
  __testing__trace__map__plan__diffs="$(__testing__trace__map__diffs "$2" "$3")" || return 1
  __testing__trace__map__plan__prior="$2"
  if ! @defined "$__testing__trace__map__plan__prior"; then
    @null __testing__trace__map__plan__prior
  fi
  @run_awk __testing__trace__map__plan__out "$__testing__trace__map__PLAN" "$__testing__trace__map__plan__prior" \
    --with "$1" \
    --with "$__testing__trace__map__plan__diffs" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" || return 1
  println "$__testing__trace__map__plan__out"
}

: <<'FUN'
Prints, per commit a prior entry was traced at, the files whose content
differs between that commit and the one this run records, as
{<commit>: [paths]}: the facts an entry is carried forward on. A commit
this clone does not hold is left out, with a note, so its entries are
traced again; a run that records no commit has nothing to compare and
prints no commit at all.

  __testing__trace__map__diffs "$prior" '"9fa43442..."'
  ->  {"1a2b3c4d...": ["lib/string/api.sh"]}

args:
  $1  The prior map, or empty
  $2  The commit this run records (a struct string, or null)
FUN
__testing__trace__map__diffs() {
  if ! @defined "$1" || ! @defined "$2"; then
    @obj __testing__trace__map__diffs__out
    println "$__testing__trace__map__diffs__out"
    return 0
  fi
  @run_awk __testing__trace__map__diffs__commits "$SHELLOPS_DIR/lib/testing/trace/entry_commits.awk" "$1" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" || return 1
  @obj __testing__trace__map__diffs__obj_17
  @unwrap __testing__trace__map__diffs__unwrap_18 "$2"
  @reduce __testing__trace__map__diffs__out __testing__trace__map__diff \
    "$__testing__trace__map__diffs__commits" \
    "$__testing__trace__map__diffs__obj_17" \
    "$__testing__trace__map__diffs__unwrap_18"
  println "$__testing__trace__map__diffs__out"
}

: <<'FUN'
@reduce callback: the files differing between one prior commit and this
run's added to the diffs under that commit, or the diffs unchanged, with a
note, when this clone does not hold the commit.

args:
  $1  The diffs so far
  $2  The prior commit (wrapped)
  $3  The commit this run records
FUN
__testing__trace__map__diff() {
  @unwrap __testing__trace__map__diff__commit "$2"
  __testing__trace__map__diff__files="$(git__differing_files \
    "$__testing__trace__map__diff__commit" \
    "$3" \
    2>/dev/null
  )" || {
    log "testing/trace: the commit $(printf '%s' "$__testing__trace__map__diff__commit" | cut -c1-8) is not in this clone; the entries traced there are traced again."
    println "$1"
    return 0
  }
  @set __testing__trace__map__diff__out "$1" ".\"$__testing__trace__map__diff__commit\"" "$__testing__trace__map__diff__files"
  println "$__testing__trace__map__diff__out"
}

: <<'FUN'
Traces the work items in order, each added to the map and kept, and prints
the map. Stops at the first file whose trace fails, so what was kept
stands and nothing is recorded past the failure: the loop a fold cannot
be, since a fold carries no failure out. Stops before a file, keeping what
it has and saying how many files are left, once the deadline has passed,
so a run on a budget ends between two files and not in the middle of one.

args:
  $1  The map to start from
  $2  The work ([{suite, file}])
  $3  The command that runs one file of a suite (struct array)
  $4  The deadline, in whole seconds since the epoch, or empty for none
FUN
__testing__trace__map__trace_each() {
  __testing__trace__map__trace_each__map="$1"
  @len __testing__trace__map__trace_each__count "$2"
  __testing__trace__map__trace_each__i=0
  while [ "$__testing__trace__map__trace_each__i" -lt "$__testing__trace__map__trace_each__count" ]; do
    if @is_true "$(__testing__trace__map__deadline_passed "$4")"; then
      log "testing/trace: the budget is spent; $((__testing__trace__map__trace_each__count - __testing__trace__map__trace_each__i)) of $__testing__trace__map__trace_each__count file(s) are left for the next run."
      break
    fi
    @get __testing__trace__map__trace_each__item "$2" ".[$__testing__trace__map__trace_each__i]"
    __testing__trace__map__trace_each__map="$(__testing__trace__map__test \
      "$__testing__trace__map__trace_each__map" \
      "$__testing__trace__map__trace_each__item" \
      "$3"
    )" || return 1
    __testing__trace__map__trace_each__i=$((__testing__trace__map__trace_each__i + 1))
  done
  println "$__testing__trace__map__trace_each__map"
}

: <<'FUN'
Prints true once the deadline <deadline> has passed, false before it; a run
with no deadline, given empty, never reaches one.

args:
  $1  The deadline, in whole seconds since the epoch, or empty
FUN
__testing__trace__map__deadline_passed() {
  if ! @defined "$1"; then
    @false __testing__trace__map__deadline_passed__out
    println "$__testing__trace__map__deadline_passed__out"
    return 0
  fi
  __testing__trace__map__deadline_passed__now="$(time__epoch_seconds)"
  @succeeds __testing__trace__map__deadline_passed__out [ "$__testing__trace__map__deadline_passed__now" -ge "$1" ]
  println "$__testing__trace__map__deadline_passed__out"
}

: <<'FUN'
One work item traced, its entry added to the map under its suite and
file, the map kept, and printed. The trace log lives only as long as the
entry takes to read.

args:
  $1  The map so far
  $2  The work item ({suite, file})
  $3  The command that runs one file of a suite (struct array)
FUN
__testing__trace__map__test() {
  @let "$2" __testing__trace__map__test__ suite file
  __testing__trace__map__test__log="$(mktemp)" || return 1

  log "testing/trace: tracing $__testing__trace__map__test__file"
  @get __testing__trace__map__test__get_19 "$1" '.commit'
  __testing__trace__map__test__entry="$(__testing__trace__map__entry \
    "$__testing__trace__map__test__log" \
    "$__testing__trace__map__test__suite" \
    "$__testing__trace__map__test__file" \
    "$3" \
    "$__testing__trace__map__test__get_19"
  )"
  __testing__trace__map__test__code=$?
  rm -f "$__testing__trace__map__test__log"
  @is_zero "$__testing__trace__map__test__code" || return 1

  @set __testing__trace__map__test__map "$1" \
    ".suites.\"$__testing__trace__map__test__suite\".tests.\"$__testing__trace__map__test__file\"" \
    "$__testing__trace__map__test__entry"
  @unlet __testing__trace__map__test__ suite file
  testing__trace__keep "$__testing__trace__map__test__map" || return 1
  println "$__testing__trace__map__test__map"
}

: <<'FUN'
One test file's entry in the map: its observation, with the status its run
under the tracer ended in and the commit it was traced at.

args:
  $1  The trace log
  $2  The suite name
  $3  The test file
  $4  The command that runs one file of a suite (struct array)
  $5  The commit this run records (a struct string, or null)
FUN
__testing__trace__map__entry() {
  __testing__trace__map__entry__status="$(__testing__trace__map__status \
    "$1" \
    "$2" \
    "$3" \
    "$4"
  )" || return 1
  __testing__trace__map__entry__seen="$(__testing__trace__observation \
    "$1" \
    "$3"
  )" || return 1
  @wrap __testing__trace__map__entry__wrap_20 "$__testing__trace__map__entry__status"
  @set __testing__trace__map__entry__out "$__testing__trace__map__entry__seen" \
    '.status' "$__testing__trace__map__entry__wrap_20" \
    '.commit' "$5"
  println "$__testing__trace__map__entry__out"
}

: <<'FUN'
Prints passed or failed: how one test file's run under the tracer ended.
Fails, saying so, when the run ended by a signal: a test cut short read
only part of what it reads, so no entry may stand on it. The command's
output goes to stderr, so the map alone comes out on stdout.

args:
  $1  The trace log
  $2  The suite name
  $3  The test file
  $4  The command that runs one file of a suite (struct array)
FUN
__testing__trace__map__status() {
  __testing__trace__map__status__code=0
  @apply __testing__trace__map__run "$1" "$2" "$3" "$4" >&2 \
    || __testing__trace__map__status__code=$?
  if [ "$__testing__trace__map__status__code" -gt 128 ]; then
    error "testing/trace: the run of $3 ended by signal $((__testing__trace__map__status__code - 128)); not recorded."
    return 1
  fi
  if @is_zero "$__testing__trace__map__status__code"; then
    println "$__testing__trace__map__STATUS_PASSED"
  else
    println "$__testing__trace__map__STATUS_FAILED"
  fi
}

: <<'FUN'
Runs one test file under the tracer: the command words follow the log, the
suite and the file, and run with the suite and the file appended.

args:
  $1  The trace log
  $2  The suite name
  $3  The test file
  $@  The command words
FUN
__testing__trace__map__run() {
  __testing__trace__map__run__log="$1"
  __testing__trace__map__run__suite="$2"
  __testing__trace__map__run__file="$3"
  shift 3
  __testing__trace__record "$__testing__trace__map__run__log" \
    "$@" \
    "$__testing__trace__map__run__suite" \
    "$__testing__trace__map__run__file"
}
