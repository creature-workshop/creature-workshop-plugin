#!/usr/bin/env bash

import "$SHELLOPS_DIR/.scripts/_pipelines_certification.sh"

# file-label-check: allow -- a plugin under .scripts is keyed outside any library root and would read as an entrypoint
:<<'DOC'
What earns shellops the rc certification: the internal, staging and public copies ran the candidate's
pipeline green, as _pipelines_certification.sh asks them. See
lib/certification/api.sh for what the roles mean.
DOC
@certification.rc() {
  @summary() {
    println "rc: the internal, staging and public copies ran the candidate's pipeline green."
  }

  @certify() {
    @arr __certification_rc__arr_1 origin mirror staging-gitlab staging-github public-gitlab public-github
    __pipelines_certification__verdicts "$__certification_rc__arr_1" "$1"
  }
}
