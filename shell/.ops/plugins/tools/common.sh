#!/usr/bin/env bash

function __shellops__tool_version() {
  local tool="$1"
  # shellcheck disable=SC2154
  local version
  if [[ -n "${SHELLOPS_TOOL_REQUIREMENTS:-}" ]]; then
    @get version "$SHELLOPS_TOOL_REQUIREMENTS" '.version'
    println "$version"
    return 0
  fi
  if [[ -n "${__tools_api__registry:-}" ]]; then
    @get version "$__tools_api__registry" ".\"$tool\".version"
    println "$version"
    return 0
  fi
  error "__shellops__tool_version: missing SHELLOPS_TOOL_REQUIREMENTS or __tools_api__registry (tool '$tool')"
  return 1
}
