#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/string/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
The .gitattributes file as data. A rule is a pattern and the attributes git
gives every path the pattern matches, and a file is a struct array of rules,
first line first:

  git__attributes__read "$repo"
    ->  [{"pattern": "*", "attributes": ["filter=lfs", "diff=lfs", "merge=lfs", "-text"]}]

An attribute keeps git's own spelling: "text" sets it, "-text" unsets it,
"!text" leaves it unspecified and "filter=lfs" gives it a value.
MODULE

: <<'PUB_FUN'
Prints the rules the .gitattributes of the directory <dir> holds, as a
struct array in the file's order; the empty array when the directory has no
such file or the file holds no rule. A blank line or a comment is no rule,
and a rule's pattern is its first word.

Usage: git__attributes__read <dir>
PUB_FUN
git__attributes__read() {
  __git__attributes__read__file="$1/.gitattributes"
  if [ ! -f "$__git__attributes__read__file" ]; then
    @arr __git__attributes__read__out
    println "$__git__attributes__read__out"
    return 0
  fi
  __git__attributes__read__lines="$(awk -f "$SHELLOPS_DIR/lib/git/attributes/rules.awk" "$__git__attributes__read__file")"
  if ! @defined "$__git__attributes__read__lines"; then
    @arr __git__attributes__read__out
    println "$__git__attributes__read__out"
    return 0
  fi
  @split __git__attributes__read__split "$__git__attributes__read__lines"

  @map __git__attributes__read__out __git__attributes__rule_of_line "$__git__attributes__read__split"
  println "$__git__attributes__read__out"
}

: <<'FUN'
@map callback: the rule the wrapped line $1 spells, as the rules program
prints one: the pattern, a tab, then the attributes joined by spaces.

  __git__attributes__rule_of_line '"*\tfilter=lfs -text"'
    ->  {"pattern": "*", "attributes": ["filter=lfs", "-text"]}
FUN
__git__attributes__rule_of_line() {
  __git__attributes__rule_of_line__tab="$(string__tab)"
  @unwrap __git__attributes__rule_of_line__line "$1"
  __git__attributes__rule_of_line__pattern="${__git__attributes__rule_of_line__line%%"$__git__attributes__rule_of_line__tab"*}"
  __git__attributes__rule_of_line__rest="${__git__attributes__rule_of_line__line#*"$__git__attributes__rule_of_line__tab"}"
  @split __git__attributes__rule_of_line__attributes "$__git__attributes__rule_of_line__rest" ' '

  git__attributes__rule "$__git__attributes__rule_of_line__pattern" "$__git__attributes__rule_of_line__attributes"
}

: <<'PUB_FUN'
Writes the rules <rules>, a struct array, as the .gitattributes of the
directory <dir>: one rule per line in the order given, in place of the file
that was there. Prints nothing.

  git__attributes__write "$repo" "$(git__attributes__lfs_everything)"

Usage: git__attributes__write <dir> <rules>
PUB_FUN
git__attributes__write() {
  @foreach __git__attributes__print_rule "$2" > "$1/.gitattributes"
}

: <<'FUN'
@foreach callback: prints the line the rule $1 takes in the file, the
pattern and then its attributes, one space between each.

  __git__attributes__print_rule '{"pattern": "*", "attributes": ["filter=lfs", "-text"]}'  ->  * filter=lfs -text
FUN
__git__attributes__print_rule() {
  @let "$1" __git__attributes__print_rule__ pattern attributes
  @join __git__attributes__print_rule__joined "$__git__attributes__print_rule__attributes" ' '

  println "$__git__attributes__print_rule__pattern${__git__attributes__print_rule__joined:+ $__git__attributes__print_rule__joined}"
  @unlet __git__attributes__print_rule__ pattern attributes
}

: <<'PUB_FUN'
Prints the rule that gives every path matching <pattern> the attributes
<attributes>, a struct array in git's spelling.

  git__attributes__rule '*.md' "$(@arr text diff=markdown)"
    ->  {"pattern": "*.md", "attributes": ["text", "diff=markdown"]}

Usage: git__attributes__rule <pattern> <attributes>
PUB_FUN
git__attributes__rule() {
  @obj __git__attributes__rule__out '.pattern' "$1" '.attributes' "$2"
  println "$__git__attributes__rule__out"
}

: <<'PUB_FUN'
Prints the rule git-lfs writes for a pattern it tracks: every path matching
<pattern> is stored as an LFS object, and is never diffed or merged as text.

  git__attributes__lfs_tracked '*.bin'
    ->  {"pattern": "*.bin", "attributes": ["filter=lfs", "diff=lfs", "merge=lfs", "-text"]}

Usage: git__attributes__lfs_tracked <pattern>
PUB_FUN
git__attributes__lfs_tracked() {
  @arr __git__attributes__lfs_tracked__attributes filter=lfs diff=lfs merge=lfs -text

  git__attributes__rule "$1" "$__git__attributes__lfs_tracked__attributes"
}

: <<'PUB_FUN'
Prints the rules of a repository that holds every file as an LFS object
except .gitattributes itself, which stays a plain text file so that git can
read the rules: what a data store's branch carries.

Usage: git__attributes__lfs_everything
PUB_FUN
git__attributes__lfs_everything() {
  __git__attributes__lfs_everything__all="$(git__attributes__lfs_tracked '*')"
  @arr __git__attributes__lfs_everything__plain '!filter' '!diff' '!merge' text
  __git__attributes__lfs_everything__self="$(git__attributes__rule .gitattributes "$__git__attributes__lfs_everything__plain")"

  @arr __git__attributes__lfs_everything__out "$__git__attributes__lfs_everything__all" "$__git__attributes__lfs_everything__self"
  println "$__git__attributes__lfs_everything__out"
}
