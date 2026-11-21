#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/args/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELL_LINT_DIR/shell/lint/api.sh"

: <<'FRAGMENT'
The jq-program check. The structs verbs are how shell code reads and builds
a structured value, and a jq program is the shape they replace. The check
reports a jq program in both places one is written: a file whose name ends
in .jq, and a call of @jq in a shell file.

The detectors are lib/structs/lint/jq_file.awk, which reads the .jq files,
and lib/structs/lint/jq_call.awk, which reads the shell files over the
shared scanner runtime, so a heredoc body is never a call.
FRAGMENT

# CONST: The directory of the detectors, absolute so the caller's cwd does not matter.
__structs__lint__jq_program__DIR="$SHELLOPS_DIR/lib/structs/lint"

# CONST: The scanner runtime the call detector is loaded with; it tracks heredocs.
__structs__lint__jq_program__RUNTIME="$SHELL_SCAN_DIR/shell/scan/scan.awk"

# CONST: The newline, which separates the paths in a list of files.
__structs__lint__jq_program__NL="
"

: <<'FUN'
Rejects a jq program among <files...>: a file whose name ends in .jq, and
a call of @jq in any other file. A file under lib/structs may call @jq,
because that module defines the verb.

When the run reports on one diff, a .jq file is reported only when that
diff adds it, so a file that git already tracks can still be edited. The
diff is the staged one under <opts>.added_only, and the commits on HEAD
since HEAD forked from the ref under <opts>.added_since.

A .jq file that has to exist has `# jq-program-check: allow` in a comment
line of its own. A call that has to stay has the same marker on its line,
or within the three lines above it.

Usage: __structs__lint__jq_program__run <opts> <files...>

Returns 0 when nothing is reported, 1 otherwise (findings printed to
stderr, as "<file>:<lineno>: <why>").
FUN
__structs__lint__jq_program__run() {
  __structs__lint__jq_program__run__hits="$(__structs__lint__jq_program__findings "$@")"
  @defined "$__structs__lint__jq_program__run__hits" || return 0

  log "$__structs__lint__jq_program__run__hits"
  return 1
}

: <<'FUN'
Prints every finding in <files...>: the reported .jq files first, then the
calls of @jq.

Usage: __structs__lint__jq_program__findings <opts> <files...>
FUN
__structs__lint__jq_program__findings() {
  __structs__lint__jq_program__findings__opts="$1"
  shift

  __structs__lint__jq_program__findings__programs="$(
    __structs__lint__jq_program__programs "$__structs__lint__jq_program__findings__opts" "$@"
  )"
  __structs__lint__jq_program__findings__callers="$(__structs__lint__jq_program__callers "$@")"

  args__call_with_lines \
    lint__call_with_existing \
    "$__structs__lint__jq_program__findings__programs" \
    __structs__lint__jq_program__scan_programs
  args__call_with_lines \
    lint__call_with_existing \
    "$__structs__lint__jq_program__findings__callers" \
    __structs__lint__jq_program__scan_callers
}

: <<'FUN'
Prints, one per line, the files among <files...> that the check reads as jq
programs: every file whose name ends in .jq, or only those the run's diff
adds when <opts> gives the run a diff.

Usage: __structs__lint__jq_program__programs <opts> <files...>
FUN
__structs__lint__jq_program__programs() {
  __structs__lint__jq_program__programs__opts="$1"
  shift

  __structs__lint__jq_program__programs__named="$(__structs__lint__jq_program__jq_files "$@")"
  @defined "$__structs__lint__jq_program__programs__named" || return 0

  if @is_false "$(__structs__lint__jq_program__reads_one_diff "$__structs__lint__jq_program__programs__opts")"; then
    println "$__structs__lint__jq_program__programs__named"
    return 0
  fi

  __structs__lint__jq_program__programs__added="$(
    __structs__lint__jq_program__added_paths "$__structs__lint__jq_program__programs__opts"
  )"
  args__call_with_lines \
    __structs__lint__jq_program__listed_among \
    "$__structs__lint__jq_program__programs__named" \
    "$__structs__lint__jq_program__programs__added"
}

: <<'FUN'
Prints true when <opts> gives the run one diff to report on, the staged
diff under added_only or the branch's under added_since, and false for a
full sweep.
FUN
__structs__lint__jq_program__reads_one_diff() {
  @option __structs__lint__jq_program__reads_one_diff__added_only "$1" added_only false
  @option __structs__lint__jq_program__reads_one_diff__since "$1" added_since ''

  if @is_true "$__structs__lint__jq_program__reads_one_diff__added_only" \
    || @defined "$__structs__lint__jq_program__reads_one_diff__since"
  then
    @true __structs__lint__jq_program__reads_one_diff__out
  else
    @false __structs__lint__jq_program__reads_one_diff__out
  fi
  println "$__structs__lint__jq_program__reads_one_diff__out"
}

: <<'FUN'
Prints, one per line, the path from the repository root of each file the
run's diff adds: the files the commits on HEAD added since HEAD forked from
the ref <opts>.added_since gives, or the files the staged diff adds when
<opts> gives no ref.
FUN
__structs__lint__jq_program__added_paths() {
  @option __structs__lint__jq_program__added_paths__since "$1" added_since ''

  if @defined "$__structs__lint__jq_program__added_paths__since"; then
    git__diff_added_name_only "$__structs__lint__jq_program__added_paths__since" HEAD
  else
    git__staged_added_files
  fi
}

: <<'FUN'
Prints, one per line, the files among <files...> whose name ends in .jq.
FUN
__structs__lint__jq_program__jq_files() {
  for __structs__lint__jq_program__jq_files__file in "$@"; do
    case "$__structs__lint__jq_program__jq_files__file" in
      *.jq) println "$__structs__lint__jq_program__jq_files__file" ;;
    esac
  done
}

: <<'FUN'
Prints, one per line, the files among <files...> whose path from the
repository root is one of <paths>, which are given one per line. A file may
be named by its absolute path or by its path from the repository root.

Usage: __structs__lint__jq_program__listed_among <paths> <files...>
FUN
__structs__lint__jq_program__listed_among() {
  __structs__lint__jq_program__listed_among__listed="$__structs__lint__jq_program__NL$1$__structs__lint__jq_program__NL"
  shift

  for __structs__lint__jq_program__listed_among__file in "$@"; do
    __structs__lint__jq_program__listed_among__indexed="$(
      git__index_path "$__structs__lint__jq_program__listed_among__file"
    )"
    case "$__structs__lint__jq_program__listed_among__listed" in
      *"$__structs__lint__jq_program__NL$__structs__lint__jq_program__listed_among__indexed$__structs__lint__jq_program__NL"*)
        println "$__structs__lint__jq_program__listed_among__file"
        ;;
    esac
  done
}

: <<'FUN'
Prints, one per line, the files among <files...> in which a call of @jq is
a finding: every file that is not a jq program and is not under
lib/structs.
FUN
__structs__lint__jq_program__callers() {
  for __structs__lint__jq_program__callers__file in "$@"; do
    case "$__structs__lint__jq_program__callers__file" in
      *.jq) ;;
      */lib/structs/*|lib/structs/*) ;;
      *) println "$__structs__lint__jq_program__callers__file" ;;
    esac
  done
}

: <<'FUN'
Prints a finding, "<file>:1: <why>", for each of the jq program <files...>
that has no allow marker, every file in one awk.
FUN
__structs__lint__jq_program__scan_programs() {
  awk -f "$__structs__lint__jq_program__DIR/jq_file.awk" "$@"
}

: <<'FUN'
Prints a finding, "<file>:<lineno>: <why>", for each call of @jq in the
shell <files...> that no allow marker covers, every file in one awk.
FUN
__structs__lint__jq_program__scan_callers() {
  awk \
    -f "$__structs__lint__jq_program__RUNTIME" \
    -f "$__structs__lint__jq_program__DIR/jq_call.awk" \
    "$@"
}
