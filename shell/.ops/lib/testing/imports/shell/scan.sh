#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/args/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Reading the files a shell file loads, as the shell reads them: the reader the
shell-family providers answer @edges through.

One awk pass over every file of a language answers for all of them: the
shared shell lexer (lib/git/shell_lex.awk) splits each command into words, so
a loading word inside quotes or a heredoc body never counts; continuations.awk
first joins a backslash-continued command into the one line the shell runs;
prefilter.awk spares the lexer every line that can neither open a heredoc nor
load a file; and targets.awk prints the arguments of every command whose word
loads a file. edges.awk then resolves each target to the project-relative
file it names.
MODULE

__testing__imports__shell__scan__DIR="$SHELLOPS_DIR/lib/testing/imports/shell"
__testing__imports__shell__scan__EDGES="$__testing__imports__shell__scan__DIR/edges.awk"

: <<'PUB_FUN'
Prints the loads among <files> (one per line, $PROJ-relative) as a struct
array of {from, to} edges, project-relative and unique, for a shell-family
provider whose loading words are <loaders> (a struct array) and whose roots
are <roots> (a struct object of variable name -> directory). A target no
static read can name is left out.

  testing__imports__shell__edges '[".", "import"]' '{"SHELLOPS_DIR": "/repo"}' 'lib/git/api.sh'
  ->  [{"from": "lib/git/api.sh", "to": "lib/structs/api.sh"}, ...]

Usage: testing__imports__shell__edges <loaders> <roots> <files>
PUB_FUN
testing__imports__shell__edges() {
  __testing__imports__shell__IMPORTS_SHELL_EDGES_TARGETS="$(testing__imports__shell__scan_targets "$PROJ" "$1" "$3")" || return 1
  @split __testing__imports__shell__IMPORTS_SHELL_EDGES_LINES "$__testing__imports__shell__IMPORTS_SHELL_EDGES_TARGETS" || return 1

  @run_awk __testing__imports__shell__edges__out "$__testing__imports__shell__scan__EDGES" \
    "$__testing__imports__shell__IMPORTS_SHELL_EDGES_LINES" \
    --with "$2" \
    --arg proj "$PROJ" \
    --load "$SHELLOPS_DIR/lib/testing/testing.awk" \
    --load "$SHELLOPS_DIR/lib/testing/imports/edges.awk" || return 1
  println "$__testing__imports__shell__edges__out"
}

: <<'PUB_FUN'
Prints the loads the files under <root> make, one per line as
"<file>TAB<target>": the file relative to <root>, and the target as written,
quotes bound away but variables unexpanded. <loaders> is the struct array
of loading words and <files> the files to read, one per line, relative to
<root>.

  testing__imports__shell__scan_targets "$PROJ" '[".", "import"]' 'lib/git/api.sh'
  ->  lib/git/api.sh<TAB>$SHELLOPS_DIR/lib/structs/api.sh
      lib/git/api.sh<TAB>$SHELLOPS_DIR/lib/string/api.sh

Usage: testing__imports__shell__scan_targets <root> <loaders> <files>
PUB_FUN
testing__imports__shell__scan_targets() {
  @join __testing__imports__shell__IMPORTS_SCAN_TARGETS_LOADERS "$2" ' '
  (
    cd "$1" || exit 1
    args__call_with_lines __testing__imports__shell__scan__awk "$3" "$__testing__imports__shell__IMPORTS_SCAN_TARGETS_LOADERS"
  )
}

: <<'FUN'
Runs the scanner over <files...> in the current directory, with <loaders> the
space-separated loading words. Prints nothing for no files.

Usage: __testing__imports__shell__scan__awk <loaders> [file...]
FUN
__testing__imports__shell__scan__awk() {
  __testing__imports__shell__scan__awk__loaders="$1"
  shift
  [ "$#" -gt 0 ] || return 0

  awk \
    -v loaders="$__testing__imports__shell__scan__awk__loaders" \
    -f "$__testing__imports__shell__scan__DIR/continuations.awk" \
    -f "$__testing__imports__shell__scan__DIR/prefilter.awk" \
    -f "$SHELLOPS_DIR/lib/git/shell_lex.awk" \
    -f "$__testing__imports__shell__scan__DIR/targets.awk" \
    "$@"
}
