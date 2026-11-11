#!/bin/sh
# shellcheck disable=SC2119  # bare @arr/@obj are the structs empty constructors

import "$SHELLOPS_DIR/lib/structs/api.sh"
import "$SHELLOPS_DIR/lib/args/api.sh"
import "$SHELLOPS_DIR/lib/fingerprint/probe.sh"
import "$SHELLOPS_DIR/lib/fingerprint/_line.sh"
import "$SHELLOPS_DIR/lib/fingerprint/report.sh"

:<<'FRAGMENT'
The declaration surface: a module states the inputs it reads, and the chain
and default each one resolves through.
FRAGMENT

:<<'PUB_FUN'
Declares one secret this module reads, as the chain of variable names it falls
back through in preference order. A lone name is a chain of one.

A declaration states a fact about the module holding it, so it belongs beside
that module's imports and carries no default: a literal default for a secret is
either useless or a leak, and the value comes from the environment.

Usage: fingerprint__secret FORGE_PR_TOKEN CI_JOB_TOKEN
PUB_FUN
fingerprint__secret() {
  if @is_true "$(args__empty "$@")"; then
    error "fingerprint__secret: a secret is at least one variable name"
    return 1
  fi

  case "$1" in
    *=*)
      error "fingerprint__secret: a secret takes no default: $1"
      return 1
      ;;
  esac

  @arr __fingerprint__secret__arr_1 "$@"
  __fingerprint__declare secret "$__fingerprint__secret__arr_1" ''
}

:<<'PUB_FUN'
Declares one non-secret input this module reads, as the chain of variable names
it falls back through in preference order, the first optionally carrying the
default its reader uses when nothing supplies a value. That default is bound on
the first name when no name in the chain supplies a value, so later readers
see it. Binding runs even when reporting is off: owning the variable is not a
reporting concern.

Its value is reported rather than digested: an input that may appear in a job
log says more as itself than as a hash of itself. Declaring one is therefore an
assertion that it holds nothing a log must not carry -- what the DSL says by
typing an env entry @string rather than @secret.

Usage: fingerprint__input SHELLOPS_FORGE=gitlab
PUB_FUN
fingerprint__input() {
  if @is_true "$(args__empty "$@")"; then
    error "fingerprint__input: an input is at least one variable name"
    return 1
  fi

  @arr __fingerprint__input__names "${1%%=*}"
  __fingerprint__input__default=''
  case "$1" in
    *=*) __fingerprint__input__default="${1#*=}" ;;
  esac

  shift
  @arr __fingerprint__input__arr_2 "$@"
  @concat __fingerprint__input__names \
    "$__fingerprint__input__names" \
    "$__fingerprint__input__arr_2"

  __fingerprint__declare \
    input \
    "$__fingerprint__input__names" \
    "$__fingerprint__input__default"

  __fingerprint__bind_default \
    "$__fingerprint__input__names" \
    "$__fingerprint__input__default"
}

:<<'FUN'
Exports <default> onto the first name in <names> when no name in the chain
supplies a value.
FUN
__fingerprint__bind_default() {
  if ! @defined "$2"; then
    return 0
  fi

  if @defined "$(__fingerprint__winner "$1")"; then
    return 0
  fi

  @first __fingerprint__bind_default__first_3 "$1"
  @unwrap __fingerprint__bind_default__unwrap_4 "$__fingerprint__bind_default__first_3"
  export "$__fingerprint__bind_default__unwrap_4=$2"
}

:<<'FUN'
Holds one declaration of kind <kind> over the chain <names>, whose reader falls
back to <default> when no name in it supplies a value, for the report to pick
up. Each name's state and the name the chain resolved to are taken now, so a
later bind of the default cannot rewrite the line.
FUN
__fingerprint__declare() {
  __fingerprint__declare__mode="$(fingerprint__mode)"
  if [ "$__fingerprint__declare__mode" = off ]; then
    return 0
  fi

  __fingerprint__declare__pending="$(__fingerprint__pending)"
  @obj __fingerprint__declare__obj_5 \
      '.kind' "$1" \
      '.names' "$2" \
      '.default' "$3" \
      '.winner' "$(__fingerprint__winner "$2")" \
      '.seen' "$(__fingerprint__snapshot "$1" "$2" "$3")"
  @push __fingerprint__PENDING \
    "$__fingerprint__declare__pending" \
    "$__fingerprint__declare__obj_5"

  if [ "$__fingerprint__declare__mode" = live ]; then
    fingerprint__report >&2
  fi
}
