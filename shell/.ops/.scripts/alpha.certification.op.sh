#!/usr/bin/env bash

import "$SHELLOPS_DIR/.scripts/_pipelines_certification.sh"

# file-label-check: allow -- a plugin under .scripts is keyed outside any library root and would read as an entrypoint
:<<'DOC'
What earns shellops the alpha certification: the internal copies, origin and its mirror, ran the candidate's
pipeline green, as _pipelines_certification.sh asks them. See
lib/certification/api.sh for what the roles mean.
DOC
@certification.alpha() {
  @summary() {
    println "alpha: the internal copies, origin and its mirror, ran the candidate's pipeline green."
  }

  @certify() {
    @arr __certification_alpha__arr_1 origin mirror
    __pipelines_certification__verdicts "$__certification_alpha__arr_1" "$1"
  }
}
