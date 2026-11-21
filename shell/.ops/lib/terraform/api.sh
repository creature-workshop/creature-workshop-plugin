#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/fingerprint/api.sh" \
  "$SHELLOPS_DIR/lib/terraform/_install.sh"

: <<'MODULE'
Running terraform over a directory of configuration: whether the binary is
on PATH, an http backend initialised at a state address with its lock
beside it, the credentials that backend reads from the environment, and a
plan or an apply that takes no input. Installing the binary at the version
ops.lock pins is _install.sh, imported here.
MODULE

fingerprint__input TF_HTTP_USERNAME
fingerprint__secret TF_HTTP_PASSWORD

: <<'PUB_FUN'
Prints true when terraform is on PATH, false when it is not.

Usage: terraform__available
PUB_FUN
terraform__available() {
  @succeeds __terraform__available__out __terraform__on_path
  println "$__terraform__available__out"
}

: <<'FUN'
Succeeds quietly when terraform is on PATH.

Usage: __terraform__on_path
FUN
__terraform__on_path() {
  command -v terraform >/dev/null 2>&1
}

: <<'PUB_FUN'
Hands the http backend the user and the password it authenticates with,
through the variables terraform reads on every command, so neither is
written under the configuration directory the way a backend-config value
is.

  terraform__http_credentials blizz "$GITLAB_TOKEN"

Usage: terraform__http_credentials <user> <password>
PUB_FUN
terraform__http_credentials() {
  TF_HTTP_USERNAME="$1"
  TF_HTTP_PASSWORD="$2"
  export TF_HTTP_USERNAME TF_HTTP_PASSWORD
}

: <<'PUB_FUN'
Initialises the configuration in <dir> against the http backend at
<address>, locked through <address>/lock with POST and DELETE, the way
GitLab's managed state takes it. A directory initialised against another
backend before is reconfigured.

  terraform__init_http_backend .ops/infra https://gitlab.example.com/api/v4/projects/1/terraform/state/repo

Usage: terraform__init_http_backend <dir> <address>
PUB_FUN
terraform__init_http_backend() {
  terraform -chdir="$1" init -input=false -reconfigure \
    -backend-config="address=$2" \
    -backend-config="lock_address=$2/lock" \
    -backend-config="unlock_address=$2/lock" \
    -backend-config="lock_method=POST" \
    -backend-config="unlock_method=DELETE"
}

: <<'PUB_FUN'
Plans the configuration in <dir> without applying it, taking no input.

Usage: terraform__plan <dir>
PUB_FUN
terraform__plan() {
  terraform -chdir="$1" plan -input=false
}

: <<'PUB_FUN'
Applies the configuration in <dir>, taking no input and asking nothing.

Usage: terraform__apply <dir>
PUB_FUN
terraform__apply() {
  terraform -chdir="$1" apply -input=false -auto-approve
}
