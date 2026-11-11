#!/bin/sh

import "$SHELLOPS_DIR/lib/kinds/api.sh"

: <<'MODULE'
Deployment sites: where a deployment puts a version. A ladder
(lib/promotion/api.sh) declares its sites and says which a tag at a rung is
put at; a release puts the tagged commit at each (lib/releases/reach.sh), a
docs ingest puts a version of a project's pages at the site that keeps
them, and a certification puts a candidate at the branch a forge runs it on.
A site is a struct whose `.kind` names the plugin and whose other fields are
what that plugin reads: a branch site is one branch of a repository
(lib/git/repository.sh), a homebrew-tap site is a tap that gets the
release's formula. The kind reads `.kind` and nothing else. A site that
names no kind is inert: nothing is put through a plugin.

A site plugin is a plugin of kind site (lib/kinds/api.sh says how a kind
loads), a file named <name>.site.op.sh defining @site.<name>() with these
roles:

  @summary                      The kind of site in one line.
  @put <name> <site> <version>  Makes <version> what the site shows. The
                                version is a struct the plugin reads, as the
                                site is: for a branch {commit, tag, lease},
                                the branch moved to the commit. Prints
                                nothing. Fails, saying why, when the site
                                refuses it.

Proving a candidate at a site before its tag exists is not a site's role: a
certification does that at a site (lib/certification/api.sh). Checking a
site's content out as files is the repository's (lib/git/repository.sh).

Importing this module loads every site plugin under lib/.
MODULE

__sites__ROLES="summary put"
__sites__REQUIRED="put"

: <<'PUB_FUN'
Loads and registers the site plugin <name>, whose file has been imported.
See kinds__load.
PUB_FUN
sites__load() {
  kinds__load site "$1" "$__sites__ROLES" "$__sites__REQUIRED"
}

: <<'PUB_FUN'
Finds and loads every site plugin under <root>. See kinds__scan.
PUB_FUN
sites__load_sites() {
  kinds__scan site "$1" "$__sites__ROLES" "$__sites__REQUIRED"
}

: <<'PUB_FUN'
Prints the names of every site plugin, as a struct array, in load order.
PUB_FUN
sites__names() {
  kinds__names site
}

: <<'PUB_FUN'
Prints the site plugin <name>'s @summary, one line.
PUB_FUN
sites__summary() {
  kinds__call site "$1" summary
}

: <<'PUB_FUN'
Prints true when <site> names a kind, false for an inert site that names
none.

  sites__is_kinded '{"kind": "forges", "forges": []}'  ->  true
  sites__is_kinded '{"approvers": ["sre"]}'            ->  false

Usage: sites__is_kinded <site>
PUB_FUN
sites__is_kinded() {
  @get __sites__is_kinded__get_1 "$1" '.kind' ''
  @succeeds __sites__is_kinded__out @defined "$__sites__is_kinded__get_1"
  println "$__sites__is_kinded__out"
}

: <<'PUB_FUN'
Prints the kind of <site>: the plugin its `.kind` names. Fails when the
site names none, or one no plugin is registered under.

  sites__kind_of '{"kind": "forges", "forges": []}'  ->  forges

Usage: sites__kind_of <site>
PUB_FUN
sites__kind_of() {
  @get __sites__kind_of__kind "$1" '.kind' ''

  if ! @defined "$__sites__kind_of__kind"; then
    error "site: a site names its kind, and this one does not: $1"
    return 1
  fi

  kinds__require_known site "$__sites__kind_of__kind" || return 1
  println "$__sites__kind_of__kind"
}

: <<'PUB_FUN'
Makes <version> what the site <site>, named <name> on the ladder, shows,
through the plugin the site's kind names. Non-zero when the site names no
known kind or refuses the version.

Usage: sites__put <name> <site> <version>
PUB_FUN
sites__put() {
  __sites__put__kind="$(sites__kind_of "$2")" || return 1

  kinds__call site "$__sites__put__kind" put "$1" "$2" "$3"
}

: <<'PUB_FUN'
Prints one line per site plugin: its name and its summary.
PUB_FUN
sites__describe() {
  @foreach __sites__describe "$(sites__names)"
}

: <<'FUN'
@foreach callback: prints the listing line for the wrapped plugin <name>.
FUN
__sites__describe() {
  @unwrap __sites__describe__name "$1"
  printf '%-12s %s\n' \
    "$__sites__describe__name" \
    "$(sites__summary "$__sites__describe__name")"
}

sites__load_sites "$SHELLOPS_DIR/lib"
