#!/usr/bin/env bash

import "$SHELLOPS_DIR/lib/rust/api.sh"

rm -f "$(rustup__cargo_home)/bin/cargo-binstall"
