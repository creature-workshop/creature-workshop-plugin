#!/bin/sh

:<<'FRAGMENT'
The option constructors for GitHub calls, each on a repository the manifest names unless the caller does.
FRAGMENT

:<<'FUN'
The base every GitHub call starts from: the repository, the manifest's org
and repo unless $1 and $2 name another, and an empty token.

Usage: __github__repository_options [owner] [repo]
FUN
__github__repository_options() {
  @obj __github__repository_options__obj_1 \
    '.owner' "$(manifest__get org)" \
    '.repo'  "$(manifest__get repo)" \
    '.token' ""
  @patch __github__repository_options__out "$__github__repository_options__obj_1" \
    '.owner' "${1:-}" \
    '.repo'  "${2:-}"
  println "$__github__repository_options__out"
}

:<<'PUB_FUN'
Prints the options for creating a release on $1/$2.

Usage: github__new_github_release_options [owner] [repo]
PUB_FUN
github__new_github_release_options() {
  @set __github__new_github_release_options__out "$(__github__repository_options "${1:-}" "${2:-}")" \
    '.tag_name'   "" \
    '.name'       "" \
    '.body'       "" \
    '.prerelease' false
  println "$__github__new_github_release_options__out"
}

:<<'PUB_FUN'
Prints the options for uploading a release asset on $1/$2.

Usage: github__new_github_upload_options [owner] [repo]
PUB_FUN
github__new_github_upload_options() {
  @set __github__new_github_upload_options__out "$(__github__repository_options "${1:-}" "${2:-}")" \
    '.release_id' "" \
    '.filename'   "" \
    '.filepath'   ""
  println "$__github__new_github_upload_options__out"
}

:<<'PUB_FUN'
Prints the options for dispatching a workflow on $1/$2.

Usage: github__new_github_dispatch_options [owner] [repo]
PUB_FUN
github__new_github_dispatch_options() {
  @set __github__new_github_dispatch_options__out "$(__github__repository_options "${1:-}" "${2:-}")" \
    '.workflow' "" \
    '.ref'      ""
  println "$__github__new_github_dispatch_options__out"
}

:<<'PUB_FUN'
Prints the options for reading a workflow run on $1/$2.

Usage: github__new_github_run_options [owner] [repo]
PUB_FUN
github__new_github_run_options() {
  @set __github__new_github_run_options__out "$(__github__repository_options "${1:-}" "${2:-}")" \
    '.run_id' ""
  println "$__github__new_github_run_options__out"
}

:<<'PUB_FUN'
Prints the options for a tag on $1/$2.

Usage: github__new_github_repo_options [owner] [repo]
PUB_FUN
github__new_github_repo_options() {
  @set __github__new_github_repo_options__out "$(__github__repository_options "${1:-}" "${2:-}")" \
    '.tag' ""
  println "$__github__new_github_repo_options__out"
}

:<<'FUN'
Fills the owner, repo and number a review call may leave out: the number from
whichever of review_number and issue_number is set, since a pull request is an
issue to GitHub, and the repository from the manifest.

Usage: __github__normalize_review_options "$options"
FUN
__github__normalize_review_options() {
  @let "$1" __github__normalize_review_options__ review_number issue_number owner repo
  @defined "$__github__normalize_review_options__owner" \
    || __github__normalize_review_options__owner="$(manifest__get org)"
  @defined "$__github__normalize_review_options__repo" \
    || __github__normalize_review_options__repo="$(manifest__get repo)"

  __github__normalize_review_options__number="$__github__normalize_review_options__review_number"
  if ! @defined "$__github__normalize_review_options__number"; then
    __github__normalize_review_options__number="$__github__normalize_review_options__issue_number"
  fi

  @set __github__normalize_review_options__out "$1" \
    '.review_number' "$__github__normalize_review_options__number" \
    '.issue_number'  "$__github__normalize_review_options__number" \
    '.owner'         "$__github__normalize_review_options__owner" \
    '.repo'          "$__github__normalize_review_options__repo"
  println "$__github__normalize_review_options__out"
  __github__normalize_review_options__status=$?
  @unlet __github__normalize_review_options__ review_number issue_number owner repo
  return "$__github__normalize_review_options__status"
}
