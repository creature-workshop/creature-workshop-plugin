#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/bump/api.sh" \
  "$SHELLOPS_DIR/lib/kinds/api.sh" \
  "$SHELLOPS_DIR/lib/manifest/api.sh" \
  "$SHELLOPS_DIR/lib/versions/api.sh"

: <<'MODULE'
Promotion ladders: which rungs a repository's tags climb, which sites a tag
at each rung is put at, and which certifications a candidate for it must
earn (ADRs 000019, 000020 and 000055). A site is where a deployment puts a
version (lib/sites/api.sh): on shellops' own ladder a branch of a copy of
shellops on one of the forges it promotes across; on another ladder a
region a version is deployed to. A certification is what a candidate must
earn before its tag exists (lib/certification/api.sh); what it checks, and
where, is its own. The kind carries a site as the ladder wrote it and reads
nothing into it. A project declares the ladder it climbs in its manifest,
`promotion` (promotion__declared); one that declares none climbs no ladder,
so a release puts its tag nowhere and proves no candidate. A ladder lives
with the project's own scripts, `.scripts/<name>.promotion.op.sh`.

A ladder is a plugin of kind promotion (lib/kinds/api.sh says how a kind
loads), a file named <name>.promotion.op.sh defining @promotion.<name>() with
these roles:

  @summary           The ladder in one line. This is what a listing prints.
  @sites             Where a version is put: a struct object keyed by site
                     name, each as lib/sites/api.sh reads it. Optional; a
                     ladder that leaves it out declares none.
  @targets <rung>    The sites a tag at <rung> is put at: a struct array of
                     site names, in the order they are put. Empty for a rung
                     put nowhere. Fails for a rung the ladder does not climb,
                     so the rungs are exactly what @targets answers.
  @certifies <rung>  The certifications a candidate for <rung> must earn: a
                     struct array of their names, in the order they are
                     asked. Empty for a rung that needs none. Optional; a
                     ladder that leaves it out needs none at any rung.

A ladder carries no order of its rungs: a prerelease sits on its channel and
a clean version on stable, the versions library's word for it.

Importing this module loads every ladder under lib/ and, when the project
has one, every ladder under its .scripts/.
MODULE

__promotion__ROLES="summary sites targets certifies"
__promotion__REQUIRED="targets"
__promotion__STABLE="stable"

: <<'PUB_FUN'
Loads and registers the ladder <name>, whose plugin file has been imported.
See kinds__load.
PUB_FUN
promotion__load() {
  kinds__load promotion "$1" "$__promotion__ROLES" "$__promotion__REQUIRED"
}

: <<'PUB_FUN'
Finds and loads every ladder under <root>. See kinds__scan.
PUB_FUN
promotion__load_ladders() {
  kinds__scan promotion "$1" "$__promotion__ROLES" "$__promotion__REQUIRED"
}

: <<'PUB_FUN'
Prints the names of every ladder, as a struct array, in load order.
PUB_FUN
promotion__names() {
  kinds__names promotion
}

: <<'PUB_FUN'
Prints the ladder <name>'s @summary, one line.
PUB_FUN
promotion__summary() {
  kinds__call promotion "$1" summary
}

: <<'PUB_FUN'
Prints the sites a tag at <rung> is put at on the ladder <name>: a struct
array of site names in the order they are put, empty for a rung put
nowhere. Fails when the ladder does not climb the rung.

  promotion__targets shellops beta  ->  ["origin-staging", "staging-gitlab-main", "staging-github-main"]
  promotion__targets shellops dev   ->  []

Usage: promotion__targets <name> <rung>
PUB_FUN
promotion__targets() {
  kinds__call promotion "$1" targets "$2"
}

: <<'PUB_FUN'
Prints the certifications a candidate for <rung> must earn on the ladder
<name>: a struct array of names, in order, empty for a rung that needs none
and for a ladder that needs none. Fails when the ladder does not climb the
rung.

  promotion__certifies shellops alpha  ->  ["alpha"]
  promotion__certifies shellops dev    ->  []

Usage: promotion__certifies <name> <rung>
PUB_FUN
promotion__certifies() {
  promotion__targets "$1" "$2" > /dev/null || return 1

  if @is_true "$(kinds__answers promotion "$1" certifies)"; then
    kinds__call promotion "$1" certifies "$2"
  else
    @arr __promotion__certifies__out
    println "$__promotion__certifies__out"
  fi
}

: <<'PUB_FUN'
Prints the sites of the ladder <name>: a struct object keyed by site, each
site's value as the ladder wrote it, or an empty object for a ladder that
declares none. Fails for a ladder no plugin is registered under.

  promotion__sites shellops  ->  {"origin-staging": {"kind": "branch", "branch": "staging", "repository": {"kind": "worktree", "remote": "origin", "forge": "gitlab"}}, ...}
  promotion__sites cloud     ->  {"staging": {"approvers": ["sre"]}, "production": {"approvers": ["sre", "cto"]}}

Usage: promotion__sites <name>
PUB_FUN
promotion__sites() {
  __promotion__sites__answers="$(kinds__answers promotion "$1" sites)" || return 1

  if @is_true "$__promotion__sites__answers"; then
    kinds__call promotion "$1" sites
  else
    @obj __promotion__sites__out
    println "$__promotion__sites__out"
  fi
}

: <<'PUB_FUN'
Prints the site <site> of the ladder <name>, as the ladder wrote it, or the
struct null for a site the ladder does not declare. Fails for a ladder no
plugin is registered under.

  promotion__site shellops origin-staging  ->  {"kind": "branch", "branch": "staging", "repository": {"kind": "worktree", "remote": "origin", "forge": "gitlab"}}
  promotion__site shellops mirror          ->  null

Usage: promotion__site <name> <site>
PUB_FUN
promotion__site() {
  __promotion__site__sites="$(promotion__sites "$1")" || return 1

  @null __promotion__site__null_1
  @get __promotion__site__out "$__promotion__site__sites" ".\"$2\"" "$__promotion__site__null_1"
  println "$__promotion__site__out"
}

: <<'PUB_FUN'
Prints the name of the ladder the project's manifest declares under
`promotion`, or nothing when it declares none and so climbs no ladder.

Usage: promotion__declared
PUB_FUN
promotion__declared() {
  manifest__get promotion
}

: <<'PUB_FUN'
Prints the rung <version> sits on: its prerelease channel, or stable for a
clean version. Fails when the version does not parse. Whether a ladder climbs
that rung is the ladder's to say, through @targets.

  promotion__rung_of_version 1.2.0-rc.3  ->  rc
  promotion__rung_of_version 1.2.0       ->  stable

Usage: promotion__rung_of_version <version>
PUB_FUN
promotion__rung_of_version() {
  __promotion__rung_of_version__parsed="$(versions__parse_version "$1")" || return 1
  @get __promotion__rung_of_version__rung "$__promotion__rung_of_version__parsed" '.pre_type' ''

  if @defined "$__promotion__rung_of_version__rung"; then
    println "$__promotion__rung_of_version__rung"
  else
    println "$__promotion__STABLE"
  fi
}

: <<'PUB_FUN'
Prints the branch a hop to <version> is opened from. The version is in the
name because the merge guard reads a promotion's version off its branch.

  promotion__hop_branch 1.2.0-alpha.1  ->  promote/1.2.0-alpha.1

Usage: promotion__hop_branch <version>
PUB_FUN
promotion__hop_branch() {
  printf 'promote/%s\n' "$1"
}

: <<'PUB_FUN'
Prints true when the hop to <version> is the release pipeline's, its rung at
or below the one manifest.json's auto-promote-until names (ADR 000033), and
false when a person opens it. Fails when the version does not parse or the
manifest names a value the ladder does not rank.

  <auto-promote-until: rc>  promotion__hop_is_automatic 1.2.0-rc.1  ->  true
  <auto-promote-until: rc>  promotion__hop_is_automatic 1.2.0       ->  false

Usage: promotion__hop_is_automatic <version>
PUB_FUN
promotion__hop_is_automatic() {
  __promotion__hop_is_automatic__rung="$(promotion__rung_of_version "$1")" || return 1

  bump__rung_is_automatic "$__promotion__hop_is_automatic__rung"
}

: <<'PUB_FUN'
Prints one line per ladder: its name and its summary.
PUB_FUN
promotion__describe() {
  @foreach __promotion__describe "$(promotion__names)"
}

: <<'FUN'
@foreach callback: prints the listing line for the wrapped ladder <name>.
FUN
__promotion__describe() {
  @unwrap __promotion__describe__name "$1"
  printf '%-12s %s\n' \
    "$__promotion__describe__name" \
    "$(promotion__summary "$__promotion__describe__name")"
}

: <<'FUN'
Loads the project's own ladders, the ones under its .scripts/, when it has
any. See promotion__load_ladders.
FUN
__promotion__load_project_ladders() {
  if [ -d "${PROJ:-}/.scripts" ]; then
    promotion__load_ladders "$PROJ/.scripts"
  fi
}

promotion__load_ladders "$SHELLOPS_DIR/lib"
__promotion__load_project_ladders
