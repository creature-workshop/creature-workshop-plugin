#!/bin/sh

: <<'FRAGMENT'
Fills the machine's own details into a third-party repo's URLs. Each repo setup
file expands every URL it reads out of a repo config, so a single config serves
every distro and architecture: {distro}, {arch}, {version} and {codename}
become what detection found.

  "https://dl.example.com/{distro}/{codename}"  ->  "https://dl.example.com/ubuntu/noble"
FRAGMENT

__system_packages__expand_placeholders() {
  __system_packages__expand_placeholders__str="$1"

  __system_packages__expand_placeholders__str="$(string__replace "$__system_packages__expand_placeholders__str" "{distro}" "$__system_packages__DISTRO")"
  __system_packages__expand_placeholders__str="$(string__replace "$__system_packages__expand_placeholders__str" "{arch}" "$(xplat__arch)")"
  __system_packages__expand_placeholders__str="$(string__replace "$__system_packages__expand_placeholders__str" "{version}" "$__system_packages__OS_VERSION")"
  string__replace "$__system_packages__expand_placeholders__str" "{codename}" "$__system_packages__OS_CODENAME"
}
