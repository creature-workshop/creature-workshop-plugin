#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/homebrew/tap.sh"

:<<'DOC'
The homebrew-tap site: a Homebrew tap that gets the release's formula, the
plain one at stable and the -pre one below it. A site names its `.tap`, and
may name `.outdir`, `.asset_url` and `.artifact`; the version is
{commit, tag}, the formula written for the commit's recorded tag.
lib/sites/api.sh says what the roles mean; lib/homebrew/tap.sh does the
work.
DOC
@site.homebrew-tap() {
  @summary() {
    println "A Homebrew tap, given the release's formula: plain at stable, -pre below it."
  }

  @put() {
    @get __at1 "$3" '.commit'
    __homebrew__tap__reach "$2" "$__at1"
  }
}
