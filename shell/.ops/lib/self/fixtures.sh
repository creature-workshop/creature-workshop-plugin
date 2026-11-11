#!/bin/sh

import "$SHELLOPS_DIR/lib/git/trees/fixtures.sh"

: <<'FRAGMENT'
The on-disk shapes a test of lib/self needs standing up: what a forge
holds for a dependency that has a lock, and for one that carries a
command. They sit beside the module and outside its api, so loading
lib/self hands production code no fixture.
The repositories a tree test needs are lib/git/trees/fixtures.sh.

Nothing here knows what runs it: paths are given, not read out of a harness
variable.
FRAGMENT

: <<'PUB_FUN'
Builds two bare repositories under <dir>, standing in for a forge where a
dependency has converted: <dir>/helper.git, holding one file, and
<dir>/tool.git, holding a lock that records helper as a run-time import
at its commit and shellops as a git-channel tool at a commit the forge
does not hold. Prints the tool commit.

Usage: self__fixture_locked_forge "$BATS_TEST_TMPDIR/forge"  ->  9c2a...
PUB_FUN
self__fixture_locked_forge() {
  __self__fixture_locked_forge__helper="$(git__trees__fixture_published "$1/helper.git" lib/api.sh '# the helper')"

  git init -q -b main "$1/tool.seed"
  git__trees__fixture_identity "$1/tool.seed"
  mkdir -p "$1/tool.seed/.ops"
  printf '{\n  "dependencies": {\n    "imports": {\n      "helper": {\n        "commit": "%s"\n      }\n    },\n    "tools": {\n      "git": {\n        "shellops": {\n          "version": "0000000000000000000000000000000000000002"\n        }\n      }\n    }\n  },\n  "features": {}\n}\n' \
    "$__self__fixture_locked_forge__helper" > "$1/tool.seed/.ops/lock"
  git -C "$1/tool.seed" add -A
  git -C "$1/tool.seed" commit -q -m tool

  git init -q --bare -b main "$1/tool.git"
  git -C "$1/tool.seed" push -q "$1/tool.git" main
  git -C "$1/tool.seed" rev-parse HEAD
  rm -rf "$1/tool.seed"
}

: <<'PUB_FUN'
Adds a commit to <dir>/strata.git, the strata of
git__trees__fixture_strata_forge, that holds a lock recording one tool and
no imports: a repository that keeps a lock for its tools and has not
declared its run-time dependencies, its submodules still pinned. Prints
the new commit.

Usage: self__fixture_tools_locked_strata "$BATS_TEST_TMPDIR/forge"  ->  7d0b...
PUB_FUN
self__fixture_tools_locked_strata() {
  git clone -q "$1/strata.git" "$1/strata.seed"
  git__trees__fixture_identity "$1/strata.seed"
  mkdir -p "$1/strata.seed/.ops"
  printf '{\n  "dependencies": {\n    "tools": {\n      "system": {\n        "jq": {\n          "version": "1.6"\n        }\n      }\n    }\n  },\n  "features": {}\n}\n' > "$1/strata.seed/.ops/lock"
  git -C "$1/strata.seed" add -A
  git -C "$1/strata.seed" commit -q -m 'strata with a lock for its tools'
  git -C "$1/strata.seed" push -q origin main
  git -C "$1/strata.seed" rev-parse HEAD
  rm -rf "$1/strata.seed"
}

: <<'PUB_FUN'
Builds a bare repository at <remote>, standing in for a dependency that
carries one command: its main holds cli/<command>, an executable that
prints the command's name and then each argument on a line of its own.
Prints the commit.

Usage: self__fixture_command_forge "$BATS_TEST_TMPDIR/forge/tool.git" docs  ->  3b7e...
PUB_FUN
self__fixture_command_forge() {
  git init -q -b main "$1.seed"
  git__trees__fixture_identity "$1.seed"
  mkdir -p "$1.seed/cli"
  cp "$SHELLOPS_DIR/lib/self/command.fixture.sh" "$1.seed/cli/$2"
  chmod +x "$1.seed/cli/$2"
  git -C "$1.seed" add -A
  git -C "$1.seed" commit -q -m tool

  git init -q --bare -b main "$1"
  git -C "$1.seed" push -q "$1" main
  git -C "$1.seed" rev-parse HEAD
  rm -rf "$1.seed"
}
