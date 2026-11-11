#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/fingerprint/api.sh" \
  "$SHELLOPS_DIR/lib/kinds/api.sh" \
  "$SHELLOPS_DIR/lib/self/config.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
The deployment kind: where a project is deployed, and how. A deployment
target is a plugin of kind deployment (lib/kinds/api.sh says how a kind
loads), a file named <name>.deployment.op.sh under lib/, beside the library
it runs, defining @deployment.<name>() with these roles:

  @summary                   What the target is, in one line.
  @needs                     The programs the target runs, as a struct
                             array. The job that deploys installs them first,
                             through `cli/install --needs deployment`, which
                             reads deployment__declared_needs; a deploy
                             asserts them and installs nothing.
  @preview <project-dir>     Deploys the project as a preview and prints the
                             deploy's output, with the deployment's location
                             in it.
  @production <project-dir>  Deploys the project to production.
  @preview_url <output>      Prints the deployment's location out of a
                             preview's output, or nothing when it has none.

vercel is the first target, lib/vercel/vercel.deployment.op.sh. A
repository declares where it is deployed once, as a list, and the catalog's
deployment members run this facade with no platform in their own text:

  .ops/config/deployment.yaml:
    targets:
      - vercel

deployment__targets is that list, or the one target SHELLOPS_DEPLOY_TARGET
names when it is set, or vercel when neither says. Nothing is resolved at
import: a caller names the target in every call, as it does for any other
kind, and a deploy runs each target the repository declares.

usage:
  import "$SHELLOPS_DIR/lib/deployment/api.sh"
  deployment__assert_needs vercel || exit 1
  deployment__preview vercel <project-dir>
MODULE

: <<'CONST'
The target a deploy runs when neither SHELLOPS_DEPLOY_TARGET nor the
declaration names one. The fingerprint input for the variable binds no
default, because a bound default would stand in for the declaration's list
on every read.
CONST
__deployment__DEFAULT_TARGET="vercel"

# CONST: The roles the kind knows.
__deployment__ROLES="summary needs preview production preview_url"

# CONST: The roles a target must answer.
__deployment__REQUIRED="summary preview production preview_url"

: <<'PUB_FUN'
Prints the deployment targets a deploy runs, as a struct array of
lowercased names: the one SHELLOPS_DEPLOY_TARGET names when it is set, else
`targets` of the repository's deployment declaration, else the module
default. Fails, naming the targets there are, when one is not a loaded
target.

    deployment__targets  ->  ["vercel"]

usage: deployment__targets
PUB_FUN
deployment__targets() {
  __deployment__targets__selected="$(__deployment__selected_targets)" || return 1
  __deployment__targets__list="$(println "$__deployment__targets__selected" | tr '[:upper:]' '[:lower:]')"
  @foreach __deployment__require_target "$__deployment__targets__list" || return 1
  println "$__deployment__targets__list"
}

: <<'FUN'
Prints the targets as they are named, before the check, as a compact struct
array: a one-element array of SHELLOPS_DEPLOY_TARGET when it is set, else
the declaration's list, else the module default alone. Fails when the
declaration exists and cannot be read.
FUN
__deployment__selected_targets() {
  if @defined "${SHELLOPS_DEPLOY_TARGET:-}"; then
    @arr __deployment__selected_targets__out "$SHELLOPS_DEPLOY_TARGET"
    println "$__deployment__selected_targets__out"
    return 0
  fi
  @arr __deployment__selected_targets__default "$__deployment__DEFAULT_TARGET"
  __deployment__selected_targets__declared="$(self__config__get deployment '.targets' "$__deployment__selected_targets__default")" || return 1
  @compact __deployment__selected_targets__out "$__deployment__selected_targets__declared"
  println "$__deployment__selected_targets__out"
}

: <<'FUN'
@foreach callback: succeeds when the wrapped <target> is a loaded target,
and otherwise says which it is and which there are, and returns 1.
FUN
__deployment__require_target() {
  @unwrap __deployment__require_target__name "$1"
  if @is_true "$(kinds__registered deployment "$__deployment__require_target__name")"; then
    return 0
  fi
  @join __deployment__require_target__join_1 "$(deployment__names)" ', '
  error "Unknown deployment target: $__deployment__require_target__name. Expected one of: $__deployment__require_target__join_1."
  return 1
}

: <<'PUB_FUN'
Prints the names of every loaded deployment target, as a struct array, in
load order.

usage: deployment__names
PUB_FUN
deployment__names() {
  kinds__names deployment
}

: <<'PUB_FUN'
Prints the target <target>'s @summary.

usage: deployment__summary <target>
PUB_FUN
deployment__summary() {
  kinds__call deployment "$1" summary
}

: <<'PUB_FUN'
Prints the programs the target <target> runs, as a struct array: its
@needs, or an empty array for a target that declares none.

usage: deployment__needs <target>
PUB_FUN
deployment__needs() {
  if @is_true "$(kinds__answers deployment "$1" needs)"; then
    kinds__call deployment "$1" needs
  else
    @arr __deployment__needs__out
    println "$__deployment__needs__out"
  fi
}

: <<'PUB_FUN'
Prints the programs every target deployment__targets names runs, as one
struct array, each once: what a job that deploys installs before the
deploy starts, through `cli/install --needs deployment`. Fails as
deployment__targets does.

    deployment__declared_needs  ->  ["vercel"]

usage: deployment__declared_needs
PUB_FUN
deployment__declared_needs() {
  __deployment__declared_needs__targets="$(deployment__targets)" || return 1
  @arr __deployment__declared_needs__arr_2
  @reduce __deployment__declared_needs__out __deployment__collect_needs "$__deployment__declared_needs__targets" "$__deployment__declared_needs__arr_2"
  println "$__deployment__declared_needs__out"
}

: <<'FUN'
@reduce callback: adds the programs the wrapped <target> runs to the
accumulator, each once.
FUN
__deployment__collect_needs() {
  @unwrap __deployment__collect_needs__unwrap_3 "$2"
  @reduce __deployment__collect_needs__out __deployment__add_need "$(deployment__needs "$__deployment__collect_needs__unwrap_3")" "$1"
  println "$__deployment__collect_needs__out"
}

: <<'FUN'
@reduce callback: adds the wrapped <program> to the accumulator unless it
is there already.
FUN
__deployment__add_need() {
  @unwrap __deployment__add_need__program "$2"
  if @println "$1" | grep -qFx -- "$__deployment__add_need__program"; then
    println "$1"
  else
    @push __deployment__add_need__out "$1" "$__deployment__add_need__program"
    println "$__deployment__add_need__out"
  fi
}

: <<'PUB_FUN'
Succeeds quietly when every program the target <target> runs is on the
PATH; otherwise says what is missing and what installs it, and returns 1.
See kinds__assert_needs. A deploy calls it first for each target, so a
missing program stops the deploy before it starts; nothing here installs.

usage: deployment__assert_needs <target> || exit 1
PUB_FUN
deployment__assert_needs() {
  kinds__assert_needs deployment "$1"
}

: <<'PUB_FUN'
Deploys the project under <project-dir> as a preview on the target
<target>, and prints the deploy's output.

usage: deployment__preview <target> <project-dir>
PUB_FUN
deployment__preview() {
  kinds__call deployment "$1" preview "$2"
}

: <<'PUB_FUN'
Deploys the project under <project-dir> to production on the target
<target>.

usage: deployment__production <target> <project-dir>
PUB_FUN
deployment__production() {
  kinds__call deployment "$1" production "$2"
}

: <<'PUB_FUN'
Prints the deployment's location out of a preview's <output>, as the
target <target> reports it, or nothing when it has none.

usage: deployment__preview_url <target> <output>
PUB_FUN
deployment__preview_url() {
  kinds__call deployment "$1" preview_url "$2"
}

fingerprint__input SHELLOPS_DEPLOY_TARGET

kinds__scan deployment "$SHELLOPS_DIR/lib" "$__deployment__ROLES" "$__deployment__REQUIRED"
