#!/usr/bin/env bash

source "$SHELLOPS_DIR/plugins/tools/common.sh"
import "$SHELLOPS_DIR/lib/node/api.sh"

version="$(__shellops__tool_version fnm)"

node__install_fnm "$version"
