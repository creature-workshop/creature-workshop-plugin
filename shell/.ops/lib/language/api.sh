#!/bin/sh

: <<'MODULE'
What language a file is written in, judged from its name and, failing that,
its first line. The linter picks the checks that read a file by this answer
and the import scanner picks the provider that reads it, so both ask here and
cannot disagree on what a shell file is.

  language__of_path lib/string/api.sh       ->  shell
  language__of_path lib/markdown/lines.awk  ->  awk
  language__of_path cli/test                ->  shell   (by its shebang)
  language__of_path engine/cache/src/lib.rs ->  rust
  language__of_path engine/cache/Cargo.toml ->  cargo
  language__of_path README.md               ->  markdown
  language__of_path LICENSE                 ->  (nothing)

Nothing is the answer for a file written in none of these: the linter lists
no checks for it and the scanner reads it with no provider. The languages
this tree is written in are named here, once; a consumer of the answer reads
the ones it has checks or providers for.
MODULE

__language__LINES="$SHELLOPS_DIR/lib/language/lines.awk"

: <<'PUB_FUN'
Prints the language of the file at <path>: shell for .sh, .bats or a shell
shebang, awk for .awk, jq for .jq, markdown for .md, yaml for .yml or .yaml,
rust for .rs, cargo for a Cargo.toml manifest. Prints nothing for any other file.

Answers without a subshell, so a caller can classify a whole tree at the cost
of one function call per file.
PUB_FUN
language__of_path() {
  case "$1" in
    *.sh|*.bats) printf 'shell\n' ;;
    *.awk) printf 'awk\n' ;;
    *.jq) printf 'jq\n' ;;
    *.md) printf 'markdown\n' ;;
    *.yml|*.yaml) printf 'yaml\n' ;;
    *.rs) printf 'rust\n' ;;
    Cargo.toml|*/Cargo.toml) printf 'cargo\n' ;;
    *) __language__of_shebang "$1" ;;
  esac
}

: <<'FUN'
Prints shell when the first line of <path> is a shell shebang (#!/bin/sh,
#!/usr/bin/env bash, ...). Prints nothing otherwise, or when the file cannot
be read.
FUN
__language__of_shebang() {
  __language__of_shebang__first=""
  if [ -f "$1" ]; then
    IFS= read -r __language__of_shebang__first < "$1" || true
  fi

  case "$__language__of_shebang__first" in
    '#!'*sh|'#!'*sh' '*) printf 'shell\n' ;;
  esac
}

: <<'PUB_FUN'
Prints the language of every file named in <paths> (one per line, relative to
<root>) as one "<language>TAB<path>" line per file, in the order given. The
language is empty for a file that has none.

  language__of_paths "$PROJ" 'lib/string/api.sh
  README.md'
  ->  shell<TAB>lib/string/api.sh
      <TAB>README.md

Usage: language__of_paths <root> <paths>
PUB_FUN
language__of_paths() {
  println "$2" \
    | __language__answer_lines "$1" \
    | awk -f "$__language__LINES"
}

: <<'FUN'
Reads paths on stdin, relative to <root>, and prints for each its language on
a line of its own when it has one, then the path on a line led by a tab.
lines.awk pairs the two. Two lines rather than one because language__of_path
answers on stdout, and reading that answer into a variable would fork a
subshell per file.
FUN
__language__answer_lines() {
  while IFS= read -r __language__answer_lines__path; do
    [ -n "$__language__answer_lines__path" ] || continue
    language__of_path "$1/$__language__answer_lines__path"
    printf '\t%s\n' "$__language__answer_lines__path"
  done
}
