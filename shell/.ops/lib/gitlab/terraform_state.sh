#!/bin/sh

: <<'MODULE'
The Terraform state GitLab manages for a project: the address an http
backend reads and writes a named state at.
MODULE

: <<'PUB_FUN'
Prints the address of the state named <name> that the GitLab at <host>
manages for the project at <path>, as the http backend takes it.

  gitlab__terraform_state__address gitlab.example.com group/sub/repo repo
  ->  https://gitlab.example.com/api/v4/projects/group%2Fsub%2Frepo/terraform/state/repo

Usage: gitlab__terraform_state__address <host> <path> <name>
PUB_FUN
gitlab__terraform_state__address() {
  printf 'https://%s/api/v4/projects/%s/terraform/state/%s\n' \
    "$1" \
    "$(__gitlab__terraform_state__encoded "$2")" \
    "$3"
}

: <<'FUN'
Prints a project path as the REST API takes it in a URL, its slashes
encoded.

  __gitlab__terraform_state__encoded group/sub/repo  ->  group%2Fsub%2Frepo
FUN
__gitlab__terraform_state__encoded() {
  printf '%s' "$1" | sed 's|/|%2F|g'
}
