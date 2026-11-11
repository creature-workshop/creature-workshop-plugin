#!/bin/sh

: <<'FRAGMENT'
Fixtures for the terraform domain: a release zip shaped the way HashiCorp
ships terraform, one executable named `terraform` at its top, and the file
of sums that vouches for it. The executable is a real script under
fixtures/, and the zip of it is a real file beside it.
FRAGMENT

: <<'PUB_FUN'
Prints the version the fixture executable answers `version` with.

    terraform__fixture_version  ->  9.9.9
PUB_FUN
terraform__fixture_version() {
  "$SHELLOPS_DIR/lib/terraform/fixtures/terraform" version | sed 's/^Terraform v//'
}

: <<'PUB_FUN'
Copies the fixture zip into directory $1, creating it, under the name $2,
and prints the zip's path.

    terraform__fixture_package "$tmp" terraform_9.9.9_linux_amd64.zip
    -> $tmp/terraform_9.9.9_linux_amd64.zip
PUB_FUN
terraform__fixture_package() {
  mkdir -p "$1"
  cp "$SHELLOPS_DIR/lib/terraform/fixtures/terraform_9.9.9.zip" "$1/$2"
  println "$1/$2"
}

: <<'PUB_FUN'
Writes a file of sums under directory $1 that lists the zip at $2 by its
name with the sum $3, and prints the file's path. With no $3, the sum is
the zip's own, so the file vouches for it.

    terraform__fixture_sums "$tmp" "$zip"            -> $tmp/SHA256SUMS, matching
    terraform__fixture_sums "$tmp" "$zip" "$(printf '%064d' 0)"  -> $tmp/SHA256SUMS, not matching
PUB_FUN
terraform__fixture_sums() {
  __terraform__fixture_sums__sum="${3:-$(sha256sum "$2" | cut -d' ' -f1)}"
  mkdir -p "$1"
  printf '%s  %s\n' "$__terraform__fixture_sums__sum" "$(basename "$2")" > "$1/SHA256SUMS"
  println "$1/SHA256SUMS"
}
