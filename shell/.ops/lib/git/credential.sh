#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"
import "$SHELLOPS_DIR/lib/git/api.sh"

: <<'MODULE'
The credential section of git's configuration: which helper git asks for a
password when a server over https wants one. git reads
credential.<url>.helper and runs the command it names with the operation as
its last argument. A caller names a helper for a server on this repository's
own configuration or host-wide, names shellops's own command as that helper
with git__credential__command, and that command answers through
git__credential__answer with an account and the token an environment
variable holds, so no token is written to disk.
MODULE

: <<'PUB_FUN'
Prints the helper string that makes shellops answer git's requests for a
server as <user>, with the token the variable <token_env> holds. The string
is the command git runs, so it carries the path to this shellops; git
appends the operation when it runs it.

  git__credential__command oauth2 FORGE_ADMIN_TOKEN  ->  /opt/shellops/actions/git/credential oauth2 FORGE_ADMIN_TOKEN

Usage: git__credential__command <user> <token_env>
PUB_FUN
git__credential__command() {
  printf '%s/actions/git/credential %s %s\n' "$SHELLOPS_DIR" "$1" "$2"
}

: <<'PUB_FUN'
Prints the helper git asks for the server <url> from inside this
repository, whichever configuration names it, and nothing when none does.

Usage: git__credential__helper <url>
PUB_FUN
git__credential__helper() {
  git -C "$(__git__repo)" config --get "credential.${1}.helper" || true
}

: <<'PUB_FUN'
Prints the helper the global git configuration names for the server <url>,
and nothing when it names none.

  git__credential__helper_global https://gitlab.com  ->  /opt/shellops/actions/git/credential oauth2 FORGE_ADMIN_TOKEN

Usage: git__credential__helper_global <url>
PUB_FUN
git__credential__helper_global() {
  git config --global --get "credential.${1}.helper" || true
}

: <<'PUB_FUN'
Names <helper> as the credential helper for the server <url> on this
repository's own configuration, so every fetch and push this clone makes to
that server asks it. A helper already named for the server is replaced.
Prints nothing.

  git__credential__helper_set https://gitlab.com "$(git__credential__command oauth2 FORGE_ADMIN_TOKEN)"

Usage: git__credential__helper_set <url> <helper>
PUB_FUN
git__credential__helper_set() {
  git -C "$(__git__repo)" config "credential.${1}.helper" "$2"
}

: <<'PUB_FUN'
Names <helper> as the credential helper for the server <url> in the global
git configuration, so every clone, fetch and push to that server over https
asks it, whichever repository makes the request and before a clone exists.
A helper already named for the server is replaced. Prints nothing.

  git__credential__helper_set_global https://gitlab.com "$(git__credential__command oauth2 FORGE_ADMIN_TOKEN)"

Usage: git__credential__helper_set_global <url> <helper>
PUB_FUN
git__credential__helper_set_global() {
  git config --global "credential.${1}.helper" "$2"
}

: <<'PUB_FUN'
Answers one request from git the way a credential helper does. The request
on stdin is read and discarded. For the operation get, prints the account
<user> and the token the variable <token_env> holds, on the two lines git
reads back, and prints nothing when the variable is unset or empty, which
leaves git to its own prompt rules. Every other operation prints nothing.

  printf 'protocol=https\nhost=gitlab.com\n\n' | git__credential__answer oauth2 FORGE_ADMIN_TOKEN get
  ->  username=oauth2
      password=glpat-...

args:
  $1  The account the token signs in as
  $2  The name of the variable that holds the token
  $3  The operation git asks for: get, store or erase

Usage: git__credential__answer <user> <token_env> <operation>
PUB_FUN
git__credential__answer() {
  __git__credential__answer__user="$1"
  __git__credential__answer__token_env="$2"
  __git__credential__answer__operation="$3"

  __git__credential__discard_request
  if [ "$__git__credential__answer__operation" != get ]; then
    return 0
  fi

  __git__credential__answer__token="$(__git__credential__token "$__git__credential__answer__token_env")"
  if ! @defined "$__git__credential__answer__token"; then
    return 0
  fi

  printf 'username=%s\npassword=%s\n' "$__git__credential__answer__user" "$__git__credential__answer__token"
}

: <<'FUN'
Reads the request git writes on stdin, the protocol and the host, and
discards it: the configuration already limits the helper to one server.
FUN
__git__credential__discard_request() {
  cat >/dev/null
}

: <<'FUN'
Prints the value of the variable named <token_env>, and nothing when it is
unset.
FUN
__git__credential__token() {
  eval "printf '%s\n' \"\${$1:-}\""
}
