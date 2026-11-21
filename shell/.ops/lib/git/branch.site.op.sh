#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/git/_branch_site.sh"

:<<'DOC'
The branch site: one branch of a repository, moved to the version's commit
under a lease or under the provenance rule. _branch_site.sh beside this file says
how; see lib/sites/api.sh for what the roles mean.
DOC
@site.branch() {
  @summary() {
    println "One branch of a repository: a version is a commit the branch moves to, under a lease or the provenance rule."
  }

  @put() {
    __git__branch_site__put "$1" "$2" "$3"
  }
}
