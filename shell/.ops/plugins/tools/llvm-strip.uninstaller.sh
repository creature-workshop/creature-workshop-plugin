#!/usr/bin/env bash

source "$SHELLOPS_DIR/plugins/tools/common.sh"
import "$SHELLOPS_DIR/lib/system_packages/api.sh"

version="$(__shellops__tool_version llvm-strip)"
package="llvm-${version}-tools"

rm -f /usr/local/bin/llvm-strip

system_packages__remove "$package"
