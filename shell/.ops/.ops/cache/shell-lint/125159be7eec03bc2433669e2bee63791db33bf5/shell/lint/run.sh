#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/args/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELL_LINT_DIR/shell/lint/checks.sh" \
  "$SHELL_LINT_DIR/shell/lint/config.sh" \
  "$SHELL_LINT_DIR/shell/lint/discovery.sh"

: <<'MODULE'
Running the checks over a listing of files.

Every check runs and prints its findings before the verdict, so one run shows
everything there is to fix. A check the lint declaration holds to new lines
only (`added_only`) is skipped in a full sweep, and a check it turns off
(`disabled`) is skipped in every run; each kind is named once at the end, so
nobody wonders where it went.

A run over added lines reports the findings of one diff and no others: the
staged diff when <opts>.added_only is true, or the lines the commits on HEAD
added since HEAD forked from the ref <opts>.added_since gives.
MODULE

: <<'PUB_FUN'
Runs the checks named in <selected> -- every check when it is empty -- over
the files in <listing>. Each check gets <opts> and only the files it reads.
When <opts>.added_only is true or <opts>.added_since gives a ref, every
check runs and only its findings on added lines count; otherwise the checks
<opts>.config lists under `added_only` are skipped and named. The checks it lists under `disabled`
are skipped and named in both cases.

Returns 0 when every check that ran found nothing, 1 otherwise. Findings go to
stderr as each check prints them.

Usage: lint__run <opts> <selected> <listing>
PUB_FUN
lint__run() {
  __lint__run__opts="$1"
  @join __lint__run__selected "$2" ' '
  __lint__run__listing="$3"
  @option __lint__run__added_only "$1" added_only false
  @option __lint__run__added_since "$1" added_since ''
  __lint__run__on_added="$(__lint__run__reads_added_lines)"
  @obj __lint__run__obj_1
  @get __lint__run__config "$1" '.config' "$__lint__run__obj_1"
  __lint__run__deferred_checks="$(lint__config__added_only_checks "$__lint__run__config")"
  @join __lint__run__deferred "$__lint__run__deferred_checks" ' '
  __lint__run__disabled_checks="$(lint__config__disabled_checks "$__lint__run__config")"
  @join __lint__run__disabled "$__lint__run__disabled_checks" ' '

  __lint__RUN_STATUS=0
  __lint__RUN_SKIPPED=""
  __lint__RUN_DISABLED=""

  @foreach __lint__run__one "$(lint__registry__names)"

  __lint__run__name_left_out

  return "$__lint__RUN_STATUS"
}

: <<'FUN'
Prints true when this run reports only findings on added lines, the staged
diff's or the branch's, and false when it is a full sweep.
FUN
__lint__run__reads_added_lines() {
  if @is_true "$__lint__run__added_only" || @defined "$__lint__run__added_since"; then
    @true __lint__run__reads_added_lines__out
  else
    @false __lint__run__reads_added_lines__out
  fi
  println "$__lint__run__reads_added_lines__out"
}

: <<'FUN'
Names the checks this run left out, one line for the checks held to new
lines only and one for the checks the declaration turns off, each only when
there are any.
FUN
__lint__run__name_left_out() {
  if @defined "$__lint__RUN_SKIPPED"; then
    log "ops lint: held to new lines only, per the lint declaration's added_only:$__lint__RUN_SKIPPED"
  fi
  if @defined "$__lint__RUN_DISABLED"; then
    log "ops lint: turned off, per the lint declaration's disabled:$__lint__RUN_DISABLED"
  fi
}

: <<'FUN'
@foreach callback: runs the wrapped check <name> over the files it reads, when
it is selected and not skipped, and folds its result into the run's status.
FUN
__lint__run__one() {
  @unwrap __lint__run__one__name "$1"

  if @is_false "$(__lint__run__is_selected "$__lint__run__one__name")"; then
    return 0
  fi
  if @is_true "$(__lint__run__is_disabled "$__lint__run__one__name")"; then
    __lint__RUN_DISABLED="$__lint__RUN_DISABLED $__lint__run__one__name"
    return 0
  fi
  if @is_true "$(__lint__run__is_deferred "$__lint__run__one__name")"; then
    __lint__RUN_SKIPPED="$__lint__RUN_SKIPPED $__lint__run__one__name"
    return 0
  fi

  __lint__run__one__files="$(lint__files_for \
    "$__lint__run__listing" \
    "$(lint__check_language_words "$__lint__run__one__name")" \
    "$(lint__check_scope_words "$__lint__run__one__name")"
  )"
  @defined "$__lint__run__one__files" || return 0

  if @is_true "$__lint__run__on_added"; then
    __lint__run__on_added_lines "$__lint__run__one__name" "$__lint__run__one__files" \
      || __lint__RUN_STATUS=1
  else
    __lint__run__whole "$__lint__run__one__name" "$__lint__run__one__files" \
      || __lint__RUN_STATUS=1
  fi
}

: <<'FUN'
Runs the check <name> over <files>, its findings followed by its verdict when
it has any. Returns what the check returns.

Usage: __lint__run__whole <name> <files>
FUN
__lint__run__whole() {
  args__call_with_lines lint__check_run "$2" "$1" "$__lint__run__opts" && return 0

  lint__check_verdict "$1"
  return 1
}

: <<'FUN'
Runs the check <name> over <files> and reports only the findings on lines the
run's diff added, with the check's verdict when one stays. The check reads
the working tree, so a file staged in part, or changed since the last commit,
is judged by the tree.

Returns 1 when a finding stays, 0 otherwise.

Usage: __lint__run__on_added_lines <name> <files>
FUN
__lint__run__on_added_lines() {
  __lint__run__on_added_lines__findings="$(
    args__call_with_lines lint__check_run "$2" "$1" "$__lint__run__opts" 2>&1 \
      || true
  )"
  __lint__run__on_added_lines__kept="$(
    println "$__lint__run__on_added_lines__findings" \
      | awk \
        -v added="$(args__call_with_lines __lint__run__added_lines "$2")" \
        -f "$SHELL_LINT_DIR/shell/lint/added_only_filter.awk"
  )"
  @defined "$__lint__run__on_added_lines__kept" || return 0

  log "$__lint__run__on_added_lines__kept"
  lint__check_verdict "$1"
  return 1
}

: <<'FUN'
Prints "<file>\t<line>" for every line the run's diff added to each of
<files...>, under both the spelling given and the index's, since a check
prints whichever it read.
FUN
__lint__run__added_lines() {
  for __lint__run__added_lines__file in "$@"; do
    __lint__run__added_line_numbers "$__lint__run__added_lines__file" \
      | __lint__run__added_line_keys \
        "$__lint__run__added_lines__file" \
        "$(git__index_path "$__lint__run__added_lines__file")"
  done
}

: <<'FUN'
Prints the numbers of the lines the run's diff added to <file>, one per
line: the lines the commits on HEAD added since HEAD forked from the ref
<opts>.added_since gives, or the lines the staged diff added.
FUN
__lint__run__added_line_numbers() {
  if @defined "$__lint__run__added_since"; then
    __lint__run__lines_added_since "$__lint__run__added_since" "$1"
  else
    git__staged_added_lines "$1"
  fi
}

: <<'FUN'
Prints the numbers of the lines the commits on HEAD added to <file> since
HEAD forked from <ref>, one per line.

Usage: __lint__run__lines_added_since <ref> <file>
FUN
__lint__run__lines_added_since() {
  git -C "$PROJ" diff -U0 "$1...HEAD" -- "$2" \
    | awk -f "$SHELL_LINT_DIR/shell/lint/hunk_lines.awk"
}

: <<'FUN'
Reads line numbers on stdin and prints each as "<given>\t<line>" and
"<indexed>\t<line>".
FUN
__lint__run__added_line_keys() {
  while IFS= read -r __lint__run__added_line_keys__line; do
    printf '%s\t%s\n%s\t%s\n' \
      "$1" "$__lint__run__added_line_keys__line" \
      "$2" "$__lint__run__added_line_keys__line"
  done
}

: <<'FUN'
Prints true when <name> is one of the selected checks, or when nothing was
selected and so every check runs.
FUN
__lint__run__is_selected() {
  if ! @defined "$__lint__run__selected"; then
    @true __lint__run__is_selected__out
    println "$__lint__run__is_selected__out"
    return 0
  fi

  case " $__lint__run__selected " in
    *" $1 "*) @true __lint__run__is_selected__out; println "$__lint__run__is_selected__out" ;;
    *) @false __lint__run__is_selected__out; println "$__lint__run__is_selected__out" ;;
  esac
}

: <<'FUN'
Prints true when <name> is held to new lines only and this is a full sweep,
false otherwise.
FUN
__lint__run__is_deferred() {
  if @is_true "$__lint__run__on_added"; then
    @false __lint__run__is_deferred__out
    println "$__lint__run__is_deferred__out"
    return 0
  fi

  case " $__lint__run__deferred " in
    *" $1 "*) @true __lint__run__is_deferred__out; println "$__lint__run__is_deferred__out" ;;
    *) @false __lint__run__is_deferred__out; println "$__lint__run__is_deferred__out" ;;
  esac
}

: <<'FUN'
Prints true when <name> is a check the lint declaration turns off, false
otherwise.
FUN
__lint__run__is_disabled() {
  case " $__lint__run__disabled " in
    *" $1 "*) @true __lint__run__is_disabled__out; println "$__lint__run__is_disabled__out" ;;
    *) @false __lint__run__is_disabled__out; println "$__lint__run__is_disabled__out" ;;
  esac
}
