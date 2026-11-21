#!/usr/bin/env bash

source "$SHELLOPS_DIR/plugins/tools/common.sh"
import "$SHELLOPS_DIR/lib/golang/api.sh"

version="$(__shellops__tool_version go)"

golang__install "$version"
