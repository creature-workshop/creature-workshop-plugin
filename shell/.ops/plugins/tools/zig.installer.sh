#!/usr/bin/env bash

source "$SHELLOPS_DIR/plugins/tools/common.sh"
import "$SHELLOPS_DIR/lib/zigbuild/api.sh"

version="$(__shellops__tool_version zig)"

zigbuild__install_zig "$version"
