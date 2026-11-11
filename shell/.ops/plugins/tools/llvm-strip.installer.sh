#!/usr/bin/env bash

source "$SHELLOPS_DIR/plugins/tools/common.sh"
import "$SHELLOPS_DIR/lib/system_packages/api.sh"

version="$(__shellops__tool_version llvm-strip)"
package="llvm-${version}-tools"

system_packages__install "$package"

ln -sf "/usr/bin/llvm-strip-${version}" /usr/local/bin/llvm-strip
