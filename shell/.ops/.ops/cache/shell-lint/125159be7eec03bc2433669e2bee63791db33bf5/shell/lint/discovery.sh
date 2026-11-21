#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/args/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELL_LINT_DIR/shell/lint/classify.sh" \
  "$SHELL_LINT_DIR/shell/lint/config.sh"

: <<'FRAGMENT'
Which files a lint run looks at.

A run builds one listing up front: one line per file, with its language,
scope and path (see classify.sh). Each check then takes the lines whose
language and scope it reads. Building the listing once means every file is
classified once, and every check agrees on what each file is.

With no files named, the listing is the git index under PROJ, or under
--added-since the files the branch changed. The index rather
than a directory walk, because an ignored checkout inside the tree -- a
worktree, a vendored copy, a coverage run -- is not this repository's code,
and findings against it are findings nobody here can fix. With files named,
each is listed as given, tracked or not. lint.json's `exclude` directories
apply to files under PROJ and never to a file named from outside it.
FRAGMENT

__lint__discovery__NL="
"
__lint__discovery__TAB="$(printf '\t')"

: <<'FUN'
Prints lint.json's exclude directories, one per line.
FUN
__lint__discovery__exclude_lines() {
  @join __lint__discovery__exclude_lines__out "$(lint__config__excludes "$1")" "$__lint__discovery__NL"
  println "$__lint__discovery__exclude_lines__out"
}

: <<'FUN'
Prints lint.json's test tree names, one per line.
FUN
__lint__discovery__test_tree_lines() {
  @join __lint__discovery__test_tree_lines__out "$(lint__config__test_trees "$1")" "$__lint__discovery__NL"
  println "$__lint__discovery__test_tree_lines__out"
}

: <<'PUB_FUN'
Prints the listing of every tracked file a check may read under PROJ, as
absolute paths, leaving out <config>'s exclude directories.

Usage: lint__discover_tracked <config>
PUB_FUN
lint__discover_tracked() {
  git__tracked_files "$PROJ" \
    | __lint__discovery__classify_tracked \
      "$(__lint__discovery__exclude_lines "$1")" \
      "$(__lint__discovery__test_tree_lines "$1")"
}

: <<'PUB_FUN'
Prints the listing of every file under PROJ that the commits on HEAD changed
since HEAD forked from <ref>, as absolute paths, leaving out <config>'s
exclude directories and the files those commits deleted.

Usage: lint__discover_changed <config> <ref>
PUB_FUN
lint__discover_changed() {
  git__diff_name_only "$2" HEAD \
    | __lint__discovery__classify_tracked \
      "$(__lint__discovery__exclude_lines "$1")" \
      "$(__lint__discovery__test_tree_lines "$1")"
}

: <<'FUN'
Reads PROJ-relative paths on stdin. Prints the listing line of each that
exists, is a file a check may read, and is not under one of the <excludes>.
Files under one of the test <trees> are scope tests. Both lists are one name
per line.
FUN
__lint__discovery__classify_tracked() {
  while IFS= read -r __lint__discovery__classify_tracked__rel; do
    @defined "$__lint__discovery__classify_tracked__rel" || continue
    if @is_true "$(args__call_with_lines lint__rel_is_excluded "$1" "$__lint__discovery__classify_tracked__rel")"; then
      continue
    fi
    [ -f "$PROJ/$__lint__discovery__classify_tracked__rel" ] || continue
    lint__classify "$PROJ/$__lint__discovery__classify_tracked__rel" "$2"
  done
}

: <<'PUB_FUN'
Prints the listing of the named <paths>, given one per line: each that exists
and is a file a check may read, as named. <config>'s exclude directories apply
to a path under PROJ; a path from outside PROJ is the caller's to choose.

Usage: lint__select_named <config> <paths>
PUB_FUN
lint__select_named() {
  println "$2" \
    | __lint__discovery__classify_named \
      "$(__lint__discovery__exclude_lines "$1")" \
      "$(__lint__discovery__test_tree_lines "$1")"
}

: <<'FUN'
Reads paths on stdin. Prints the listing line of each that exists, is a
file a check may read, and -- when under PROJ -- is not under one of the
<excludes>. Files under one of the test <trees> are scope tests. Both lists
are one name per line.
FUN
__lint__discovery__classify_named() {
  while IFS= read -r __lint__discovery__classify_named__path; do
    @defined "$__lint__discovery__classify_named__path" || continue
    [ -f "$__lint__discovery__classify_named__path" ] || continue
    if @is_true "$(__lint__discovery__named_is_excluded "$__lint__discovery__classify_named__path" "$1")"; then
      continue
    fi
    lint__classify "$__lint__discovery__classify_named__path" "$2"
  done
}

: <<'FUN'
Prints true when <path> is under PROJ and under one of the <excludes> (one per
line), false otherwise.
FUN
__lint__discovery__named_is_excluded() {
  __lint__discovery__named_is_excluded__rel="$(lint__rel_path "$1")"
  if [ "$__lint__discovery__named_is_excluded__rel" = "$1" ]; then
    @false __lint__discovery__named_is_excluded__out
    println "$__lint__discovery__named_is_excluded__out"
    return 0
  fi

  args__call_with_lines lint__rel_is_excluded "$2" "$__lint__discovery__named_is_excluded__rel"
}

: <<'PUB_FUN'
Prints, one per line, the paths in <listing> whose language is one of the
space-separated <languages> and whose scope is one of the space-separated
<scopes>: the words the registry kept from a check's @languages and @scopes
roles (lint__check_language_words, lint__check_scope_words).

Usage: lint__files_for <listing> <languages> <scopes>
PUB_FUN
lint__files_for() {
  println "$1" | __lint__discovery__select_lines "$2" "$3"
}

: <<'FUN'
Reads listing lines on stdin. Prints the path of each whose language is one of
the space-separated <languages> and whose scope is one of the space-separated
<scopes>.
FUN
__lint__discovery__select_lines() {
  while IFS="$__lint__discovery__TAB" read -r \
    __lint__discovery__select_lines__language \
    __lint__discovery__select_lines__scope \
    __lint__discovery__select_lines__path
  do
    @defined "$__lint__discovery__select_lines__path" || continue
    case " $1 " in
      *" $__lint__discovery__select_lines__language "*) ;;
      *) continue ;;
    esac
    case " $2 " in
      *" $__lint__discovery__select_lines__scope "*) ;;
      *) continue ;;
    esac
    println "$__lint__discovery__select_lines__path"
  done
}
