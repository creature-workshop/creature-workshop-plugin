#!/usr/bin/env bash
set -euo pipefail
. "$SHELLOPS_DIR/.envrc"

USAGE="$(cat <<HELP

Flags:
  -h, --help        Show this help text.

HELP
)"

main() {
  parse_args "$@"


}

: <<'FUN'
  Parses CLI flags.
  See USAGE for flag descriptions.
FUN
parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)  log "$USAGE" && exit 0 ;;
      *)
        log "Unknown option: $1"
        log "$USAGE"
        exit 1
        ;;
    esac
    shift
  done
}

main "$@"
