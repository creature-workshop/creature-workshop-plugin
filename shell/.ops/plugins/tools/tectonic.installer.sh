#!/usr/bin/env bash

source "$SHELLOPS_DIR/plugins/tools/common.sh"
import "$SHELLOPS_DIR/lib/tectonic/api.sh"

version="$(__shellops__tool_version tectonic)"

tectonic__install "$version"
