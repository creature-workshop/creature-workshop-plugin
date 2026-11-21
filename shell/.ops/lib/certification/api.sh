#!/bin/sh

import "$SHELLOPS_DIR/lib/kinds/api.sh"

: <<'MODULE'
Certifications: what a candidate must earn before its rung's tag exists
(ADR 000025, ADR 000044, ADR 000052). A ladder's rung names the
certifications a candidate for it must earn (lib/promotion/api.sh); each is
asked once with the candidate and decides for itself what it checks and
where. A site is where a version is put (lib/sites/api.sh) and a pipeline
is what a forge runs on a commit (lib/pipelines/api.sh); neither is a
certification, and a certification may compose either. The standard
library ships the kind and no certification: a project's certifications
are its own, under its .scripts beside its ladder. shellops' are alpha,
beta and rc, named for its rungs, each asking the forges of some of its
ladder's repositories for a green pipeline on the candidate.

A certification is a plugin of kind certification (lib/kinds/api.sh says
how a kind loads), a file named <name>.certification.op.sh defining
@certification.<name>() with these roles:

  @summary        What earns the certification, in one line.
  @certify <sha>  Checks <sha> and prints the verdicts: a struct array of
                  {check, state, url}, one per check made, check naming it
                  in the certification's own words; empty when nothing was
                  checked. A state is success, failure, none for a check
                  that never happened, or unanswered for one that could not
                  be waited for. Fails only when the certification could not
                  be carried out, for example a check that refused the
                  candidate.

Importing this module loads every certification plugin under lib/, and
the project's own under its .scripts/, beside its ladder.
MODULE

__certification__ROLES="summary certify"
__certification__REQUIRED="certify"

: <<'PUB_FUN'
Loads and registers the certification plugin <name>, whose file has been
imported. See kinds__load.
PUB_FUN
certification__load() {
  kinds__load certification "$1" "$__certification__ROLES" "$__certification__REQUIRED"
}

: <<'PUB_FUN'
Finds and loads every certification plugin under <root>. See kinds__scan.
PUB_FUN
certification__load_all() {
  kinds__scan certification "$1" "$__certification__ROLES" "$__certification__REQUIRED"
}

: <<'PUB_FUN'
Prints the names of every certification plugin, as a struct array, in load
order.
PUB_FUN
certification__names() {
  kinds__names certification
}

: <<'PUB_FUN'
Prints the certification plugin <name>'s @summary, one line.
PUB_FUN
certification__summary() {
  kinds__call certification "$1" summary
}

: <<'PUB_FUN'
Asks the certification <name> about <sha> and prints the verdicts. See
@certify. Non-zero when the certification is unknown, naming the ones there
are, or could not be carried out.

Usage: certification__certify <name> <sha>
PUB_FUN
certification__certify() {
  kinds__require_known certification "$1" || return 1

  kinds__call certification "$1" certify "$2"
}

: <<'FUN'
Loads the project's own certifications, the ones under its .scripts/, when
it has any. See certification__load_all.
FUN
__certification__load_project() {
  if [ -d "${PROJ:-}/.scripts" ]; then
    certification__load_all "$PROJ/.scripts"
  fi
}

certification__load_all "$SHELLOPS_DIR/lib"
__certification__load_project
