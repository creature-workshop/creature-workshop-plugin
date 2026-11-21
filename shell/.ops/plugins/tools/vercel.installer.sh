#!/usr/bin/env bash

source "$SHELLOPS_DIR/plugins/tools/common.sh"
import "$SHELLOPS_DIR/lib/vercel/api.sh"

version="$(__shellops__tool_version vercel)"

vercel__install_cli "$version"
