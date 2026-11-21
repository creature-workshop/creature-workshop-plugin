#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/vercel/api.sh"

:<<'DOC'
Vercel as a deployment target: one deployment plugin, over the Vercel
library (lib/vercel/api.sh). See lib/deployment/api.sh for what the roles
mean.
DOC
@deployment.vercel() {
  @summary() {
    println "Vercel: builds the project in the pipeline and uploads the prebuilt output."
  }

  @needs() {
    vercel__needs
  }

  @preview() {
    vercel__preview "$@"
  }

  @production() {
    vercel__production "$@"
  }

  @preview_url() {
    vercel__preview_url "$@"
  }
}
