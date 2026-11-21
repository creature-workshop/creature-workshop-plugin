#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/kinds/api.sh" \
  "$SHELLOPS_DIR/lib/manifest/api.sh"

: <<'FRAGMENT'
Version formats: how the part of a prerelease name after its version spells
the certification and the count, and how a plan moves one (ADR.17@global).

A format is a plugin of kind version_format (lib/kinds/api.sh says how a
kind loads), a file named <name>.version_format.op.sh defining
@version_format.<name>() with these roles, <pre> being the part of a
release name after its version and the hyphen:

  @summary               The format in one line.
  @is <pre>              Succeeds quietly when <pre> is written in this
                         format, fails quietly otherwise.
  @tier <pre>            Prints the tier <pre> carries.
  @count <pre>           Prints the count <pre> carries, nothing for a tier
                         alone.
  @name <tier> <count>   Prints the part for a tier and a count, the tier
                         alone for no count.
  @order                 Reads parts on stdin, one per line, and prints the
                         key that ranks each among the parts of one
                         version, one per line in the same order, across
                         formats: three fixed-width fields, the format's
                         precedence first, so byte order sorts the keys
                         the way the parts rank. A batch, so a reader of
                         tags keys them all in one call.
  @open <tier>           Prints the part a plan opens a series with on
                         <tier>.
  @bump <tier> <count>   Prints the part a plan moves a name on <tier> at
                         <count> to, staying on the tier.
  @dev <version> <tier> <count>
                         Prints the part a plan with no label moves a name
                         of <version> on <tier> at <count> to, the dev
                         gravity, reading the version's tags where the
                         format must.
  @tag <version> <tier>  Prints the name the next tag of <version> on
                         <tier> takes, read off the tags.
  @trunk <version> <tier>
                         Prints what the trunk's manifest holds for
                         <version> on <tier>. Optional: a format that leaves
                         it out has the trunk hold a tag's name, written by
                         the release job.

Every reader takes each format's names, since a repository's history keeps
its older tags for good, and a part is read by the first format whose @is
accepts it. A plan writes the format the manifest declares under
version-format, increment when it declares none; a repository moves to a
format with its next version, since the parts of one version rank by the
format's precedence before anything else. lib/versions/api.sh loads every
format under lib/ when it is imported.
FRAGMENT

# CONST: The roles the kind knows, in the order the module doc lists them.
__versions__format__ROLES="summary is tier count name order open bump dev tag trunk"

# CONST: The roles every format must answer: every one but summary and trunk.
__versions__format__REQUIRED="is tier count name order open bump dev tag"

# CONST: The format a repository writes when its manifest declares none.
__versions__format__DEFAULT="increment"

: <<'CONST'
The names of the loaded formats, space-joined in load order, set once at
load so a reader of tags starts no subshell per tag.
CONST
__versions__format__NAMES=""

: <<'PUB_FUN'
Finds and loads every format under <root>. See kinds__scan.
PUB_FUN
versions__format__load_formats() {
  kinds__scan version_format "$1" "$__versions__format__ROLES" "$__versions__format__REQUIRED" || return 1
  @join __versions__format__NAMES "$(kinds__names version_format)" ' '
}

: <<'PUB_FUN'
Prints the names of every format, as a struct array, in load order.
PUB_FUN
versions__format__names() {
  kinds__names version_format
}

: <<'PUB_FUN'
Calls the role <role> of the format <name> with the arguments after them.
See kinds__call.

Usage: versions__format__call <name> <role> [args...]
PUB_FUN
versions__format__call() {
  kinds__call version_format "$@"
}

: <<'PUB_FUN'
Prints the format the part <pre> of a release name is written in, the first
whose @is accepts it in load order; fails naming <pre> when none does.

  versions__format_of dev.9  ->  increment
  versions__format_of 9.dev  ->  counter
  versions__format_of dev    ->  counter
PUB_FUN
versions__format_of() {
  if ! __versions__format_of "$1"; then
    error "'$1' is not a prerelease part any format reads"
    return 1
  fi

  println "$__versions__format_of__format"
}

: <<'FUN'
Sets __versions__format_of__format to what versions__format_of prints for
<pre>, failing quietly when no format reads it, without a subshell.
FUN
__versions__format_of() {
  for __versions__format_of__format in $__versions__format__NAMES; do
    if kinds__call version_format "$__versions__format_of__format" is "$1"; then
      return 0
    fi
  done

  return 1
}

: <<'PUB_FUN'
Prints the format the repository writes: the one its manifest declares
under version-format, and increment when it declares none or carries no
manifest. Fails naming the value when it names no format.

  versions__format  ->  counter    (version-format: counter)
  versions__format  ->  increment  (no manifest)
PUB_FUN
versions__format() {
  __versions__format__name="$__versions__format__DEFAULT"
  if @is_true "$(manifest__present)"; then
    __versions__format__name="$(manifest__get version_format)" || return 1
  fi

  kinds__require_known version_format "$__versions__format__name" || return 1
  println "$__versions__format__name"
}

: <<'PUB_FUN'
Prints true when the format the repository writes names what its trunk
holds, so a landing on the trunk is tagged as it is and nothing is
committed; false when the trunk holds a tag's name the release job writes.

  versions__format__has_trunk_name  ->  true   (version-format: counter)
PUB_FUN
versions__format__has_trunk_name() {
  __versions__format__has_trunk_name__format="$(versions__format)" || return 1

  kinds__answers version_format "$__versions__format__has_trunk_name__format" trunk
}

: <<'PUB_FUN'
Prints what the trunk's manifest holds for <version> on <tier> in the
format the repository writes. Fails when that format has the trunk hold a
tag's name instead.

  versions__format__trunk_name 0.67.0 dev  ->  0.67.0-dev   (version-format: counter)
PUB_FUN
versions__format__trunk_name() {
  __versions__format__trunk_name__format="$(versions__format)" || return 1

  versions__format__call "$__versions__format__trunk_name__format" trunk "$1" "$2"
}

: <<'PUB_FUN'
Prints the name the next tag of <version> on <tier> takes in the format the
repository writes, read off the tags.

  versions__format__tag_name 0.67.0 dev  ->  0.67.0-4.dev   (version-format: counter, tags up to 3)
PUB_FUN
versions__format__tag_name() {
  __versions__format__tag_name__format="$(versions__format)" || return 1

  versions__format__call "$__versions__format__tag_name__format" tag "$1" "$2"
}
