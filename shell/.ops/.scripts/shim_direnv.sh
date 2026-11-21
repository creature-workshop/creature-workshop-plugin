#!/usr/bin/env bash
# shellcheck disable=SC2016

shell_rc__add_line \
  "direnv hook" \
  'eval "$(direnv hook bash)"'
