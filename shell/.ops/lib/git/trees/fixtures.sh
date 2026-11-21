#!/bin/sh

: <<'MODULE'
The on-disk shapes a test of lib/git/trees needs standing up: what a forge
holds for a repository that pins submodules, and a repository with an
origin to resolve its dependencies beside. They sit beside the module and
outside its api, so loading lib/git/trees hands production code no fixture.

Nothing here knows what runs it: paths are given, not read out of a harness
variable. A test of another module builds its forge from these too.
MODULE

: <<'PUB_FUN'
Builds three bare repositories under <dir>, standing in for the forge:
<dir>/shell-logs.git, holding a logger; <dir>/shellops.git, holding one
file; and <dir>/strata.git, holding a SILT library at shell/silt/api.sh
that defines silt__fixture_answer, with shell-logs pinned at shell/.logs
and shellops at shell/.ops the way submodules pin them, and a .gitmodules
naming both beside strata. Prints the strata commit.

Usage: git__trees__fixture_strata_forge "$BATS_TEST_TMPDIR/forge"  ->  4f1c...
PUB_FUN
git__trees__fixture_strata_forge() {
  __git__trees__fixture_strata_forge__logs="$(git__trees__fixture_published "$1/shell-logs.git" shell/log/api.sh '# the logger')"
  __git__trees__fixture_strata_forge__ops="$(git__trees__fixture_published "$1/shellops.git" init '# the vendored resolver')"

  git init -q -b main "$1/strata.seed"
  git__trees__fixture_identity "$1/strata.seed"
  mkdir -p "$1/strata.seed/shell/silt"
  printf 'silt__fixture_answer() {\n  printf "silt\\n"\n}\n' > "$1/strata.seed/shell/silt/api.sh"
  __git__trees__fixture_gitmodules "$1/strata.seed" shell/.logs ../shell-logs.git
  __git__trees__fixture_gitmodules "$1/strata.seed" shell/.ops ../shellops.git
  git -C "$1/strata.seed" add -A
  git -C "$1/strata.seed" update-index --add --cacheinfo "160000,$__git__trees__fixture_strata_forge__logs,shell/.logs"
  git -C "$1/strata.seed" update-index --add --cacheinfo "160000,$__git__trees__fixture_strata_forge__ops,shell/.ops"
  git -C "$1/strata.seed" commit -q -m strata

  git init -q --bare -b main "$1/strata.git"
  git -C "$1/strata.seed" push -q "$1/strata.git" main
  git -C "$1/strata.seed" rev-parse HEAD
  rm -rf "$1/strata.seed"
}

: <<'PUB_FUN'
Builds a repository at <dir> whose origin is <forge>/host.git, so the
dependencies it declares resolve beside that forge, with a test identity
and one commit.

Usage: git__trees__fixture_host "$BATS_TEST_TMPDIR/host" "$BATS_TEST_TMPDIR/forge"
PUB_FUN
git__trees__fixture_host() {
  git init -q -b main "$1"
  git__trees__fixture_identity "$1"
  git -C "$1" commit -q --allow-empty -m host
  git -C "$1" remote add origin "$2/host.git"
}

: <<'FUN'
Adds the submodule at <path>, fetched from <url>, to the .gitmodules of
the repository at <dir>.

Usage: __git__trees__fixture_gitmodules <dir> <path> <url>
FUN
__git__trees__fixture_gitmodules() {
  git config -f "$1/.gitmodules" "submodule.$2.path" "$2"
  git config -f "$1/.gitmodules" "submodule.$2.url" "$3"
}

: <<'PUB_FUN'
Builds a bare repository at <remote> whose main holds one commit with one
file, <path> holding <text>, and prints the commit.

Usage: git__trees__fixture_published <remote> <path> <text>
PUB_FUN
git__trees__fixture_published() {
  git init -q -b main "$1.seed"
  git__trees__fixture_identity "$1.seed"
  mkdir -p "$(dirname "$1.seed/$2")"
  println "$3" > "$1.seed/$2"
  git -C "$1.seed" add -A
  git -C "$1.seed" commit -q -m seed

  git init -q --bare -b main "$1"
  git -C "$1.seed" push -q "$1" main
  git -C "$1.seed" rev-parse HEAD
  rm -rf "$1.seed"
}

: <<'PUB_FUN'
Adds one commit to main of the bare repository at <remote>: <path>
holding <text>, on top of what main holds. Prints the commit.

Usage: git__trees__fixture_later <remote> <path> <text>
PUB_FUN
git__trees__fixture_later() {
  git clone -q "$1" "$1.later"
  git__trees__fixture_identity "$1.later"
  mkdir -p "$(dirname "$1.later/$2")"
  println "$3" > "$1.later/$2"
  git -C "$1.later" add -A
  git -C "$1.later" commit -q -m later
  git -C "$1.later" push -q "$1" main
  git -C "$1.later" rev-parse HEAD
  rm -rf "$1.later"
}

: <<'PUB_FUN'
Gives the repository at <dir> a test identity and no signing, so a commit
needs no key and names no person.

Usage: git__trees__fixture_identity <dir>
PUB_FUN
git__trees__fixture_identity() {
  git -C "$1" config user.name test
  git -C "$1" config user.email test@example.com
  git -C "$1" config commit.gpgSign false
}
