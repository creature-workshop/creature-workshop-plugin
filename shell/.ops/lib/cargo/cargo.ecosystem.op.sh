#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/cargo/ecosystem.sh"

:<<'DOC'
The cargo ecosystem: one ecosystem plugin, its release roles first (ADR
000008). See lib/ecosystems/api.sh for what the roles mean.
DOC
@ecosystem.cargo() {
  @summary() {
    println "A Rust crate or workspace whose version follows the release."
  }

  @sync_version() {
    __cargo__ecosystem__sync_version "$1"
  }

  @version_files() {
    __cargo__ecosystem__version_files
  }
}
