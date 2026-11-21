#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/http/api.sh" \
  "$SHELLOPS_DIR/lib/self/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/xplat/api.sh"

: <<'MODULE'
Terraform as a pinned tool.

HashiCorp publishes each release as one zip per platform beside a file of
SHA256 sums. This library fetches the version ops.lock pins into the tools
home, checks the zip against the published sum before it unpacks it, and
puts the binary on PATH, so a job on a plain image provisions terraform like
any other tool, the tools cache carries it between jobs, and a bump is a
lock change. api.sh, the module's public surface, imports this file; the
tool plugin beside it, terraform.tool.op.sh, hands the version over.
MODULE

__terraform__BASE_URL="https://releases.hashicorp.com/terraform"

: <<'PUB_FUN'
Prints the directory terraform versions install under: TERRAFORM_HOME when
set, otherwise the terraform entry of the tools home.
PUB_FUN
terraform__home() {
  println "${TERRAFORM_HOME:-$(self__tool_home .terraform)}"
}

: <<'PUB_FUN'
Prints the install directory for terraform version $1, the one PATH gets.
PUB_FUN
terraform__install_dir() {
  println "$(terraform__home)/terraform-$1"
}

: <<'PUB_FUN'
Prints the name of the release zip for terraform version $1 on this
platform, which HashiCorp spells as xplat does: linux or darwin over amd64
or arm64.

    terraform__zip_name 1.16.4  ->  terraform_1.16.4_linux_amd64.zip
PUB_FUN
terraform__zip_name() {
  __terraform__zip_name__os="$(xplat__os)" || return 1
  println "terraform_$1_${__terraform__zip_name__os}_$(xplat__arch).zip"
}

: <<'PUB_FUN'
Prints the URL of the release zip for terraform version $1 on this platform.

    terraform__zip_url 1.16.4
    -> https://releases.hashicorp.com/terraform/1.16.4/terraform_1.16.4_linux_amd64.zip
PUB_FUN
terraform__zip_url() {
  __terraform__zip_url__name="$(terraform__zip_name "$1")" || return 1
  println "${__terraform__BASE_URL}/$1/${__terraform__zip_url__name}"
}

: <<'PUB_FUN'
Prints the URL of the file of SHA256 sums HashiCorp publishes beside the
zips of terraform version $1.

    terraform__sums_url 1.16.4
    -> https://releases.hashicorp.com/terraform/1.16.4/terraform_1.16.4_SHA256SUMS
PUB_FUN
terraform__sums_url() {
  println "${__terraform__BASE_URL}/$1/terraform_$1_SHA256SUMS"
}

: <<'PUB_FUN'
Prints true when terraform version $1 is installed in the tools home, false
otherwise.
PUB_FUN
terraform__installed() {
  @succeeds __terraform__installed__out [ -x "$(terraform__install_dir "$1")/terraform" ]
  println "$__terraform__installed__out"
}

: <<'PUB_FUN'
Installs terraform version $1 into the tools home and puts it on PATH. The
version comes from ops.lock through the tool plugin, the one place it is
written; an empty one fails. The zip is checked against the sum HashiCorp
publishes for it, and a zip that does not match installs nothing. A version
already installed is only put on PATH.
PUB_FUN
terraform__install() {
  if ! @defined "${1:-}"; then
    error "terraform__install: a version is required; ops.lock pins it"
    return 1
  fi

  if @is_true "$(terraform__installed "$1")"; then
    log "terraform $1 already installed"
    __terraform__export_env "$1"
    return 0
  fi

  __terraform__install__url="$(terraform__zip_url "$1")" || return 1
  log "downloading terraform $1 from $__terraform__install__url"
  __terraform__download_verify_extract "$1" || return 1
  __terraform__export_env "$1"
  log "terraform $1 ready"
}

: <<'PUB_FUN'
Removes terraform version $1 from the tools home.
PUB_FUN
terraform__uninstall() {
  rm -rf "$(terraform__install_dir "$1")"
}

: <<'FUN'
Downloads the zip and the sums for version $1 into a temporary directory,
checks the zip against its published sum, and unpacks it into the install
directory for the version. A refused download or a sum that does not match
leaves the install directory absent.
FUN
__terraform__download_verify_extract() {
  __terraform__download_verify_extract__tmp="$(mktemp -d)"
  __terraform__download_verify_extract__name="$(terraform__zip_name "$1")"
  __terraform__download_verify_extract__zip="$__terraform__download_verify_extract__tmp/$__terraform__download_verify_extract__name"
  __terraform__download_verify_extract__sums="$__terraform__download_verify_extract__tmp/SHA256SUMS"

  @false __terraform__download_verify_extract__ok
  if http__download "$(terraform__zip_url "$1")" "$__terraform__download_verify_extract__zip" \
    && http__download "$(terraform__sums_url "$1")" "$__terraform__download_verify_extract__sums" \
    && __terraform__verify "$__terraform__download_verify_extract__zip" "$__terraform__download_verify_extract__sums"; then
    __terraform__extract "$__terraform__download_verify_extract__zip" "$1"
    @true __terraform__download_verify_extract__ok
  fi

  rm -rf "$__terraform__download_verify_extract__tmp"
  @is_true "$__terraform__download_verify_extract__ok"
}

: <<'FUN'
Succeeds when the SHA256 sum of the zip at $1 is the one the sums file at
$2 lists for a file of its name; fails, saying so, otherwise.
FUN
__terraform__verify() {
  __terraform__verify__name="$(basename "$1")"
  __terraform__verify__expected="$(grep "  $__terraform__verify__name\$" "$2" | cut -d' ' -f1)"
  __terraform__verify__actual="$(__terraform__sha256 "$1")"

  if ! @defined "$__terraform__verify__expected"; then
    error "terraform: the published sums list no $__terraform__verify__name"
    return 1
  fi
  if [ "$__terraform__verify__expected" != "$__terraform__verify__actual" ]; then
    error "terraform: $__terraform__verify__name does not match its published sum"
    return 1
  fi
}

: <<'FUN'
Prints the SHA256 sum of the file at $1, by whichever of sha256sum and
shasum the host has.
FUN
__terraform__sha256() {
  if command -v sha256sum > /dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

: <<'FUN'
Unpacks the terraform binary from the zip at $1 into the install directory
for version $2.
FUN
__terraform__extract() {
  __terraform__extract__dir="$(terraform__install_dir "$2")"
  mkdir -p "$__terraform__extract__dir"
  unzip -oq "$1" terraform -d "$__terraform__extract__dir"
}

: <<'FUN'
Puts the install directory of version $1 on PATH, for this shell and for
every later shell that sources .envrc.
FUN
__terraform__export_env() {
  __terraform__export_env__dir="$(terraform__install_dir "$1")"
  export PATH="${__terraform__export_env__dir}:${PATH}"
  self__add_persistent_path "$__terraform__export_env__dir"
}
