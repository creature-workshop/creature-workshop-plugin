#!/bin/sh

: <<'MODULE'
Enforcement for the structs API boundary: the backend's representation must not
leak into consumer code. The checks police that one boundary, so they share the
scanners, the exemptions, and the allow-marker escape hatch:

  * raw backend commands (`jq`, `opx`) used outside the `@`-sigil verb surface
  * bare empty `[]` / `{}` literals where `@obj` / `@arr` belong
  * a bare `true` / `false` printed by hand where `@true` / `@false` belong,
    or `@succeeds` when an if/else exists only to print one
  * `-z` / `-n` asked of a value a command printed, where `@defined` belongs
  * a value held to the literal `true` / `false` in a test, where `@is_true`
    and `@is_false` belong
  * `@let` / `@unlet` called inside `$(...)` or a pipe, where the bindings
    die with the subshell
  * a `@let` with no `@unlet` naming the same prefix and keys before its
    function's closing brace, or bound under a prefix that is not the
    function's own
  * a `case` arm made of one word a function in the same file prints, a
    literal or a constant assigned by hand, where `@enum` binds the set
  * the positional parameters grown by hand with `set -- "$@" ...`, where
    `@apply` runs a command over a struct array
  * a value held to a spelling by hand -- a `case` pattern running a
    character class across it, an anchored `grep`, a `=~` -- where a
    `@type` plugin's `is` belongs

Lives under the structs module because it guards that module's boundary --
lib/structs/** and `*.jq` script files are the only place the backend is allowed
to surface directly; @jq is the runtime escape hatch.
MODULE

import \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELL_LINT_DIR/shell/lint/api.sh"

# CONST: The directory of the awk programs, absolute so the caller's cwd does not matter.
__structs__lint__DIR="$SHELLOPS_DIR/lib/structs/lint"

# CONST: The scanner runtime every program is loaded with; it tracks the heredocs.
__structs__lint__RUNTIME="$SHELL_SCAN_DIR/shell/scan/scan.awk"

: <<'FUN'
The structs module and *.jq scripts are the sanctioned backend surface.
FUN
__structs__lint__is_surface() {
  case "$1" in
    *.jq) return 0 ;;
    */lib/structs/*|lib/structs/*) return 0 ;;
  esac
  return 1
}

: <<'FUN'
The interpreter and op builtins predate the structs API and never import it:
their `{}` and `true` are values handed straight to raw jq, so routing them
through the constructors would bolt a structs dependency onto the interpreter
runtime. OPS-236 replaces that layer wholesale; until then its literals belong
to the backend, not to consumer code. Their raw jq/opx calls stay reported --
that is the OPS-236 backlog, and hiding it here would erase the only record of
it.
FUN
__structs__lint__is_raw_backend_layer() {
  case "$1" in
    */interpreter/*|interpreter/*) return 0 ;;
    */builtins/*|builtins/*) return 0 ;;
  esac
  return 1
}

: <<'FUN'
True when <file> is out of scope for the check driven by <detector>.
FUN
__structs__lint__is_exempt() {
  __structs__lint__is_surface "$2" && return 0
  [ "$1" = raw_backend.awk ] && return 1
  [ "$1" = spelling_test.awk ] && __structs__lint__is_type_plugin "$2" && return 0
  __structs__lint__is_raw_backend_layer "$2"
}

: <<'FUN'
True when <file> is a type plugin, <name>.type.op.sh, or its lowered copy,
<name>.type.sh: the is role is the one place a value is held to its
spelling.
FUN
__structs__lint__is_type_plugin() {
  case "$1" in
    *.type.op.sh|*.type.sh) return 0 ;;
  esac
  return 1
}

: <<'FUN'
Prints "<file>:<lineno>:<line>" for each line of <file> that <detector> rejects
and no '# structs-lint: allow' marker covers.
FUN
__structs__lint__scan_file() {
  [ -f "$2" ] || return 0

  awk \
    -v fname="$2" \
    -f "$__structs__lint__RUNTIME" \
    -f "$__structs__lint__DIR/$1" \
    -f "$__structs__lint__DIR/boundary_scan.awk" \
    "$2"
}

: <<'FUN'
Same as __structs__lint__scan_file, but reports only lines added in <file>'s
staged diff.

It scans the whole staged blob and filters by added line number rather than
scanning the diff text, because a diff shows too little context to tell whether
a hunk sits inside a heredoc -- and prose mentioning "{}" is not a violation.
FUN
__structs__lint__scan_staged() {
  __structs__lint__scan_staged__added="$(git__staged_added_lines "$2" | tr '\n' ',')"
  [ -n "$__structs__lint__scan_staged__added" ] || return 0

  __structs__lint__scan_staged__indexed="$(git__index_path "$2")"
  git -C "$PROJ" show ":$__structs__lint__scan_staged__indexed" \
    | awk \
      -v fname="$2" \
      -v added="$__structs__lint__scan_staged__added" \
      -f "$__structs__lint__RUNTIME" \
      -f "$__structs__lint__DIR/$1" \
      -f "$__structs__lint__DIR/boundary_scan.awk" \
      -
}

: <<'FUN'
  Runs <detector> over <files...> via <scanner>, printing every offender it
  finds. Both scanners detect the same way -- one detector, the same heredoc
  and allow-marker handling -- and differ in which lines they report and how
  many awks they run: __structs__lint__scan_file reports any line and runs
  once over every file, __structs__lint__scan_staged reports only the lines
  the staged diff added and reads one staged blob per awk.

  Usage: __structs__lint__audit <scanner> <detector> <files...>

  Returns 0 when every file is clean, 1 otherwise.
FUN
__structs__lint__audit() {
  __structs__lint__audit__scanner="$1"
  __structs__lint__audit__detector="$2"
  shift 2

  if [ "$__structs__lint__audit__scanner" = __structs__lint__scan_file ]; then
    __structs__lint__audit__hits="$(__structs__lint__scan_files_not_exempt "$@")"
  else
    __structs__lint__audit__hits="$(__structs__lint__scan_each_staged "$@")"
  fi
  [ -n "$__structs__lint__audit__hits" ] || return 0

  log "$__structs__lint__audit__hits"
  return 1
}

: <<'FUN'
Scans, in one awk, the files among <files...> that exist and that the
detector __structs__lint__audit named does not exempt.
FUN
__structs__lint__scan_files_not_exempt() {
  __structs__lint__scan_files_not_exempt__count=$#
  __structs__lint__scan_files_not_exempt__i=0
  while [ "$__structs__lint__scan_files_not_exempt__i" -lt "$__structs__lint__scan_files_not_exempt__count" ]; do
    if ! __structs__lint__is_exempt "$__structs__lint__audit__detector" "$1"; then
      set -- "$@" "$1"
    fi
    shift
    __structs__lint__scan_files_not_exempt__i=$((__structs__lint__scan_files_not_exempt__i + 1))
  done

  lint__call_with_existing __structs__lint__scan_files "$@"
}

: <<'FUN'
Prints "<file>:<lineno>:<line>" for each line of <files...> that the
detector __structs__lint__audit named rejects and no '# structs-lint: allow'
marker covers, every file in one awk.
FUN
__structs__lint__scan_files() {
  awk \
    -f "$__structs__lint__RUNTIME" \
    -f "$__structs__lint__DIR/$__structs__lint__audit__detector" \
    -f "$__structs__lint__DIR/boundary_scan.awk" \
    "$@"
}

: <<'FUN'
Prints the staged-diff findings of every file in <files...> the detector
does not exempt, one staged blob per awk.
FUN
__structs__lint__scan_each_staged() {
  for __structs__lint__scan_each_staged__file in "$@"; do
    __structs__lint__is_exempt \
      "$__structs__lint__audit__detector" "$__structs__lint__scan_each_staged__file" && continue
    __structs__lint__scan_staged \
      "$__structs__lint__audit__detector" "$__structs__lint__scan_each_staged__file"
  done
}

: <<'FUN'
Prints the scanner <opts> selects: the staged-blob scanner under
`.added_only`, which reports only lines the staged diff added, and the
whole-file scanner otherwise.
FUN
__structs__lint__scanner_for() {
  if @option __structs__lint__scanner_for__option_1 "$1" added_only false; @is_true "$__structs__lint__scanner_for__option_1"; then
    printf '__structs__lint__scan_staged\n'
  else
    printf '__structs__lint__scan_file\n'
  fi
}

: <<'FUN'
  Rejects raw structured-data backend commands (`jq`, `opx`) used outside the
  sanctioned structs API. The structs module (lib/structs/**) and `*.jq` script
  files are the only place the backend is allowed to surface directly; @jq is
  the runtime escape hatch for arbitrary filters.

  Under <opts>.added_only only calls on lines newly added in the staged diff
  are flagged -- the pre-commit mode that polices new code without blocking on
  the pre-existing backlog.

  A genuine raw-backend call that the verb surface cannot express may be kept by
  marking it with a `# structs-lint: allow` comment on, or within three lines
  above, the offending line (and explaining why, per house style).

  Usage: __structs__lint__no_raw_jq <opts> <files...>

  Returns 0 if no unsanctioned calls are found, 1 otherwise (offenders printed
  to stderr).
FUN
__structs__lint__no_raw_jq() {
  __structs__lint__no_raw_jq__structs_lint_no_raw_jq__scanner="$(__structs__lint__scanner_for "$1")"
  shift

  __structs__lint__audit "$__structs__lint__no_raw_jq__structs_lint_no_raw_jq__scanner" raw_backend.awk "$@"
}

: <<'FUN'
  Rejects bare empty array and object literals in consumer code, where `@arr`
  and `@obj` are the house idiom. A literal spells out how the current backend
  renders an empty struct, which hard-codes jq into every caller; the
  constructors keep that detail behind the API.

  Exempt: the structs module and `*.jq` scripts (there the literal *is* the
  backend representation), and the pre-API interpreter/builtins layer slated
  for replacement under OPS-236. Under <opts>.added_only only literals on lines
  newly added in the staged diff are flagged -- the pre-commit mode.

  A literal the constructors cannot express may be kept by marking it with a
  `# structs-lint: allow` comment on, or within three lines above, the offending
  line (and explaining why, per house style).

  Usage: __structs__lint__no_empty_literals <opts> <files...>

  Returns 0 if no bare empty literals are found, 1 otherwise (offenders printed
  to stderr).
FUN
__structs__lint__no_empty_literals() {
  __structs__lint__no_empty_literals__structs_lint_no_empty_literals__scanner="$(__structs__lint__scanner_for "$1")"
  shift

  __structs__lint__audit "$__structs__lint__no_empty_literals__structs_lint_no_empty_literals__scanner" empty_literal.awk "$@"
}

: <<'FUN'
  Rejects an argument list grown by hand -- `set -- "$@" <more>` -- in consumer
  code, where `@apply` runs a command with a struct array's elements as its
  arguments. The shape is the append: `set --` with `"$@"` as its first kept
  word. A `set --` that resets or rebinds the positionals outright is not
  reported.

  Exempt: the structs module, whose verbs are where the positionals are rebuilt
  on purpose. Under <opts>.added_only only lines newly added in the staged diff
  are flagged -- the pre-commit mode.

  A rebuild the verbs cannot express may be kept by marking it with a
  `# structs-lint: allow` comment on, or within three lines above, the offending
  line (and explaining why, per house style).

  Usage: __structs__lint__no_argv_accumulation <opts> <files...>

  Returns 0 if no hand-grown argument list is found, 1 otherwise (offenders
  printed to stderr).
FUN
__structs__lint__no_argv_accumulation() {
  __structs__lint__no_argv_accumulation__scanner="$(__structs__lint__scanner_for "$1")"
  shift

  __structs__lint__audit "$__structs__lint__no_argv_accumulation__scanner" argv_accumulation.awk "$@"
}

: <<'FUN'
  Rejects a bare `true` or `false` printed by hand in consumer code -- `printf
  'true\n'`, `echo false`, `printf '%s\n' true` -- where `@true` and `@false`
  are the house idiom, and `@succeeds <command>` when the answer is a command's
  exit status. A literal opening an if or else branch body is reported once per
  `if`, at the `if` line the `@succeeds` rewrite replaces; that `if` line is
  the one <opts>.added_only and `# structs-lint: allow` read.

  Exempt: the structs module and `*.jq` scripts, and the pre-API
  interpreter/builtins layer slated for replacement under OPS-236. Under
  <opts>.added_only only literals on newly added lines are flagged. A printed
  true or false that is not a struct boolean may be kept by marking it with a
  `# structs-lint: allow` comment on, or within three lines above, its line.

  Usage: __structs__lint__no_boolean_literals <opts> <files...>

  Returns 0 if no hand-spelled booleans are found, 1 otherwise (offenders
  printed to stderr).
FUN
__structs__lint__no_boolean_literals() {
  __structs__lint__no_boolean_literals__structs_lint_no_boolean_literals__scanner="$(__structs__lint__scanner_for "$1")"
  shift

  __structs__lint__audit "$__structs__lint__no_boolean_literals__structs_lint_no_boolean_literals__scanner" boolean_literal.awk "$@"
}

: <<'FUN'
  Rejects a `-z` or `-n` test on a value a command printed, where `@defined`
  is the question. A structs answer is one: `@get` prints the string null for
  a missing key, and `-z` / `-n` read null as present. The test wraps a
  `$(...)` substitution, or names a variable the same function last assigned
  from one; a later assignment from anything else releases it.

  Exempt: the structs module and `*.jq` scripts, and the pre-API
  interpreter/builtins layer slated for replacement under OPS-236. Under
  <opts>.added_only only tests on newly added lines are flagged. A test that
  genuinely wants the string's length may be kept by marking it with a
  `# structs-lint: allow` comment on, or within three lines above, its line.

  Usage: __structs__lint__no_string_tests <opts> <files...>

  Returns 0 if no such tests are found, 1 otherwise (offenders printed to
  stderr).
FUN
__structs__lint__no_string_tests() {
  __structs__lint__no_string_tests__structs_lint_no_string_tests__scanner="$(__structs__lint__scanner_for "$1")"
  shift

  __structs__lint__audit "$__structs__lint__no_string_tests__structs_lint_no_string_tests__scanner" defined_test.awk "$@"
}

: <<'FUN'
  Rejects a test that holds a value to the literal true or false -- `[ "$x" =
  true ]`, `[ "$(f)" != true ]`, `test "$x" = false` -- where `@is_true` and
  `@is_false` ask the question. The literal spells the backend's
  representation of a boolean into the caller; the verbs keep it behind the
  API, and only the struct spelling passes them.

  Exempt: the structs module and `*.jq` scripts, and the pre-API
  interpreter/builtins layer slated for replacement under OPS-236. Under
  <opts>.added_only only tests on newly added lines are flagged. A test that
  genuinely compares a string to the word true may be kept by marking it with
  a `# structs-lint: allow` comment on, or within three lines above, its line.

  Usage: __structs__lint__no_boolean_tests <opts> <files...>

  Returns 0 if no such tests are found, 1 otherwise (offenders printed to
  stderr).
FUN
__structs__lint__no_boolean_tests() {
  __structs__lint__no_boolean_tests__scanner="$(__structs__lint__scanner_for "$1")"
  shift

  __structs__lint__audit "$__structs__lint__no_boolean_tests__scanner" boolean_test.awk "$@"
}

: <<'FUN'
  Rejects `@let` or `@unlet` called inside a command substitution or on the
  right of a pipe: both run in a subshell, so the bindings never reach the
  caller and the unset releases nothing. A statement-position call is the
  only shape that does what it says.

  Exempt: the structs module and `*.jq` scripts. Under <opts>.added_only only
  calls on newly added lines are flagged. A call that genuinely wants the
  subshell may be kept by marking it with a `# structs-lint: allow` comment
  on, or within three lines above, its line.

  Usage: __structs__lint__no_subshell_let <opts> <files...>

  Returns 0 if no such calls are found, 1 otherwise (offenders printed to
  stderr).
FUN
__structs__lint__no_subshell_let() {
  __structs__lint__no_subshell_let__structs_lint_no_subshell_let__scanner="$(__structs__lint__scanner_for "$1")"
  shift

  __structs__lint__audit "$__structs__lint__no_subshell_let__structs_lint_no_subshell_let__scanner" subshell_let.awk "$@"
}

: <<'FUN'
  Rejects a `@let` that no `@unlet` releases before its function's closing
  brace, an `@unlet` whose prefix or keys differ from the `@let` it pairs
  with, an `@unlet` releasing what no `@let` in the function bound, and a
  `@let` bound under a prefix other than the function's own `__<name>__`.
  POSIX sh has no scope end to hang an automatic unset on, so the pair is
  what releases a binding, and the lint holds the pair together. Early
  returns are not read.

  Exempt: the structs module and `*.jq` scripts. Under <opts>.added_only only
  findings on newly added lines are reported. A binding that genuinely
  outlives its function may be kept by marking its `@let` with a
  `# structs-lint: allow` comment on, or within three lines above, its line.

  Usage: __structs__lint__let_pairs <opts> <files...>

  Returns 0 if every @let is paired, 1 otherwise (offenders printed to
  stderr).
FUN
__structs__lint__let_pairs() {
  __structs__lint__let_pairs__structs_lint_let_pairs__scanner="$(__structs__lint__scanner_for "$1")"
  shift

  __structs__lint__audit "$__structs__lint__let_pairs__structs_lint_let_pairs__scanner" let_pairing.awk "$@"
}

: <<'FUN'
  Rejects a case arm that is one word a printf or echo in the same file
  prints, a bare literal or a constant the file assigns by hand: an enum
  written by hand, where @enum binds the set once. A constant @enum bound is
  assigned nowhere, so a declared enum's arms pass; true and false stay with
  the boolean check. Arms settle when the file ends, since the printing
  function may come later. Exempt: the structs module, `*.jq` scripts, and
  the interpreter/builtins layer (OPS-236). Under <opts>.added_only only arms
  on added lines are flagged; a `# structs-lint: allow` marker on, or within
  three lines above, an arm exempts it.

  Usage: __structs__lint__no_enum_arms <opts> <files...>
  Returns 0 when every file is clean, 1 otherwise (offenders on stderr).
FUN
__structs__lint__no_enum_arms() {
  __structs__lint__no_enum_arms__structs_lint_no_enum_arms__scanner="$(__structs__lint__scanner_for "$1")"
  shift
  __structs__lint__audit "$__structs__lint__no_enum_arms__structs_lint_no_enum_arms__scanner" enum_arm.awk "$@"
}

: <<'PUB_FUN'
  Rejects a value held to a spelling by hand: a case arm whose pattern runs a
  character class naming a range or a negation across the value (`*[!0-9]*`,
  `[0-9]*`), a grep handed a
  pattern anchored at both ends and no file to read, or a bash `=~` against
  an anchored regex. That is a type written by hand, where a plugin's
  <name>_is holds the spelling once and @is_<name> asks it. A class over one
  character (`[Yy]`) or of listed punctuation, and a grep over a file, pass. Exempt: type plugins
  themselves, the structs module, `*.jq` scripts, and the interpreter/builtins
  layer (OPS-236). Under <opts>.added_only only lines the staged diff added
  are flagged; a `# structs-lint: allow` marker on, or within three lines
  above, a line exempts it.

  Usage: structs__lint__no_spelling_tests <opts> <files...>
  Returns 0 when every file is clean, 1 otherwise (offenders on stderr).
PUB_FUN
structs__lint__no_spelling_tests() {
  __structs__lint__no_spelling_tests__scanner="$(__structs__lint__scanner_for "$1")"
  shift
  __structs__lint__audit "$__structs__lint__no_spelling_tests__scanner" spelling_test.awk "$@"
}
