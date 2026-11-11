#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/bump/api.sh" \
  "$SHELLOPS_DIR/lib/ecosystems/api.sh" \
  "$SHELLOPS_DIR/lib/forge/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/manifest/api.sh" \
  "$SHELLOPS_DIR/lib/releases/files.sh" \
  "$SHELLOPS_DIR/lib/releases/_land.sh" \
  "$SHELLOPS_DIR/lib/releases/record/api.sh" \
  "$SHELLOPS_DIR/lib/releases/record/commit.sh" \
  "$SHELLOPS_DIR/lib/versions/api.sh"

: <<'MODULE'
Preparing a release on the default branch, and publishing it. A repository
whose version format names what the trunk holds, the version and its
certification alone (versions__format__has_trunk_name), is tagged at its
tip and nothing is committed, the landing job of lib/releases/_land.sh
(ADR.44@shellops). A repository whose trunk holds a tag's name releases as
a record on the branch: the version planned from the labels of the
reviews merged since the last tag, the manifest and every ecosystem's
version files synced, one commit naming those reviews, the tag on that
commit, the commit pushed with the forge asked to run nothing for it and the
tag pushed on its own so its run happens, and then the forge release for
the tag.

What a release writes is the repository's own declaration: manifest.json
always, and every version file the ecosystems the manifest declares name
(lib/ecosystems/api.sh). A repository declaring no ecosystem releases
manifest.json alone.

releases__release_prepare is the one place a version is recorded: the release commit on
the default branch carries manifest.json and the synced version files, names
the merge requests the release covers, and is the commit the tag lands on. The
commit pushes first and the tag only once the commit has landed, so a rejected
push never leaves an orphan tag behind; on rejection it re-plans against the
moved tip and pushes again, bounded by RELEASE_PUSH_ATTEMPTS.
MODULE

RELEASE_PUSH_ATTEMPTS="${RELEASE_PUSH_ATTEMPTS:-5}"

: <<'CONST'
What the default branch's tip can already hold for a version; releases__tip_state
answers one of these and releases__cut_release dispatches on it.
CONST
@enum __releases__TIP TAGGED RECORDED UNRELEASED

@false __releases__prepared

: <<'CONST'
True once releases__release_prepare has pushed a release, so a caller running both
phases knows whether there is anything to publish.
CONST
__releases__PREPARED="$__releases__prepared"

: <<'PUB_FUN'
Prepares the release on the default branch: syncs the forge labels, then
tags the landing when the manifest holds the trunk's name, and otherwise
plans the version and cuts the release for it. Outcomes, and what brings
each about:

  landed              the version format names what the trunk holds, the
                      version and dev alone (ADR.44@shellops): the tip is
                      tagged the version's next dev and nothing is
                      committed. lib/releases/_land.sh says what each
                      outcome means.
  nothing to plan     no merge request landed since the last tag: a re-run,
                      or a push with no reviews behind it. Returns 0.
  already tagged      the planned version has a tag, either form: the
                      pipeline re-ran on a tip that already released. Returns 0.
  already recorded    the tip's manifest.json already holds the version: a
                      branch that carried its own plan commit, or a hand
                      edit. No commit; the tip is tagged and the tag pushed.
  release             merge requests landed since the last tag: manifest and
                      the ecosystems' files synced, one commit naming them,
                      tag, the commit pushed and then the tag.
  branch moved        another merge landed while this ran, so the push was
                      rejected: local tag dropped, reset onto the new tip,
                      re-planned fresh. Nothing left to cut ends clean; else
                      retried up to RELEASE_PUSH_ATTEMPTS, then failed.
  planning failed     the merged reviews' labels contradict each other
                      (two meta/ channels), or the version is not semver. Exits 1.
  off the branch      a web, api or trigger pipeline on any other ref, in CI:
                      refused before anything is touched. Exits 1.
  off the rc          the plan is a stable a promotion earned and the tip
                      holds something other than the rc's tag. Exits 1.
PUB_FUN
releases__release_prepare() {
  releases__assert_default_branch_ci

  releases__sync_forge_labels

  if @is_true "$(versions__format__has_trunk_name)"; then
    releases__release_land || exit 1
    @true __releases__PREPARED
    return 0
  fi

  if ! __releases__release_prepare__version="$(releases__plan_version)"; then
    error "Version planning failed (see log above)."
    exit 1
  fi
  if ! @defined "$__releases__release_prepare__version"; then
    log "No bump needed; skipping release."
    return 0
  fi
  log "Planned version: $__releases__release_prepare__version"
  releases__check_stable_earned_from_rc "$__releases__release_prepare__version"

  releases__cut_release "$__releases__release_prepare__version"
}

: <<'PUB_FUN'
Refuses the cut when version $1 is a stable a promotion earned and the tip
does not hold what the rc's tag holds. A stable is earned from the rc it was
proven as (ADR 000025), and ops promote checks the same before it opens the
merge request; this is the check the tag itself is priced at, so nothing
landed between the two mints a stable no forge ran.

A clean version on a repository releasing per merge is nobody's promotion
(ADR 000029) and is not gated, and neither is a prerelease.

  <default-channel: dev>  releases__check_stable_earned_from_rc 0.66.0-dev.4  ->  passes, ungated
  <default-channel: dev>  releases__check_stable_earned_from_rc 0.66.0        ->  exits 1 off the rc tag
PUB_FUN
releases__check_stable_earned_from_rc() {
  __releases__check_stable_earned_from_rc__promoted="$(releases__stable_is_promoted "$1")" || exit 1
  if @is_false "$__releases__check_stable_earned_from_rc__promoted"; then
    return 0
  fi

  __releases__check_stable_earned_from_rc__rc="$(releases__record__get_latest)"
  __releases__check_stable_earned_from_rc__tag="$(versions__tag_for_version "$__releases__check_stable_earned_from_rc__rc")"
  if ! @defined "$__releases__check_stable_earned_from_rc__tag"; then
    fatal "release prepare: refusing to cut $1: no tag records $__releases__check_stable_earned_from_rc__rc, the version the tip declares, so there is no rc for it to stand at."
    exit 1
  fi

  if @is_true "$(releases__tip_stands_at "$__releases__check_stable_earned_from_rc__tag")"; then
    return 0
  fi

  __releases__check_stable_earned_from_rc__head="$(git__commit_of HEAD)"
  fatal "release prepare: refusing to cut $1: HEAD ($__releases__check_stable_earned_from_rc__head) does not stand at the $__releases__check_stable_earned_from_rc__tag tag, so the stable would ship what the rc was never proven with. Promote to rc again, then release that rc."
  exit 1
}

: <<'PUB_FUN'
Prints true when version $1 is one a promotion earned: a clean version on a
repository whose ordinary merge plans a dev prerelease instead (ADR 000029),
so meta/release is the only label that plans it.

  <default-channel: dev>     releases__stable_is_promoted 0.66.0       ->  true
  <default-channel: dev>     releases__stable_is_promoted 0.66.0-rc.1  ->  false
  <default-channel: stable>  releases__stable_is_promoted 0.66.0       ->  false
PUB_FUN
releases__stable_is_promoted() {
  if ! versions__is_release_version "$1"; then
    @false __releases__stable_is_promoted__out
    println "$__releases__stable_is_promoted__out"
    return
  fi

  __releases__stable_is_promoted__channel="$(bump__default_channel)" || return 1

  @succeeds __releases__stable_is_promoted__out [ "$__releases__stable_is_promoted__channel" != stable ]
  println "$__releases__stable_is_promoted__out"
}

: <<'PUB_FUN'
Prints true when the tip holds exactly what tag $1 holds, compared by tree,
so a promotion's own empty commit on top of the tag still stands at it.
PUB_FUN
releases__tip_stands_at() {
  git__trees_match HEAD "$1"
}

: <<'PUB_FUN'
Creates the forge release for the tag recorded in the manifest, attaching
the files the artifacts file $1 names when one is given.

Usage: releases__release_publish [artifacts_file]
PUB_FUN
releases__release_publish() {
  if @defined "${1:-}"; then
    "$SHELLOPS_DIR/cli/publish-release" --artifacts "$1"
    return
  fi

  "$SHELLOPS_DIR/cli/publish-release"
}

: <<'PUB_FUN'
Prints the tag this run releases, in whichever form the repository wrote it:
the tag the pipeline runs for when it names a version, else the version tag
on HEAD, else the tag recording the lock's latest version. Fails naming
that version when none of the three is a tag: a publish has nothing to
release until the version is tagged. On the default branch the lock holds
the version and its certification alone, which no tag records, so a tag's
pipeline is read by its tag (ADR.17@global).

  releases__release_recorded_tag  ->  0.67.0-4.dev   (the tag the pipeline runs for, or the one on HEAD)
  releases__release_recorded_tag  ->  v0.18.2        (the lock's version, tagged)

Usage: releases__release_recorded_tag
PUB_FUN
releases__release_recorded_tag() {
  if versions__is_valid_semver "${CI_COMMIT_TAG:-}"; then
    println "$CI_COMMIT_TAG"
    return 0
  fi

  __releases__release_recorded_tag__at="$(versions__tag_at HEAD 2>/dev/null)"
  if @defined "$__releases__release_recorded_tag__at"; then
    println "$__releases__release_recorded_tag__at"
    return 0
  fi

  __releases__release_recorded_tag__latest="$(releases__record__get_latest)"
  __releases__release_recorded_tag__tag="$(versions__tag_for_version "$__releases__release_recorded_tag__latest")"
  if ! @defined "$__releases__release_recorded_tag__tag"; then
    error "no tag records the lock's latest version ($__releases__release_recorded_tag__latest); tried $__releases__release_recorded_tag__latest and v$__releases__release_recorded_tag__latest"
    return 1
  fi

  println "$__releases__release_recorded_tag__tag"
}

: <<'PUB_FUN'
Prints true once releases__release_prepare has pushed a release in this process, false
until then.
PUB_FUN
releases__release_prepared() {
  println "$__releases__PREPARED"
}

: <<'PUB_FUN'
CI containment: releases__release_prepare pushes to the default branch, so in CI it may
only run from a pipeline on that branch. Any other ref reaching here is a
misrouted pipeline (an api/web-source trigger on a feature branch, or a
rules regression) and the only safe response is a hard refusal. Outside CI
(no CI variable), local/manual use is untouched.
PUB_FUN
releases__assert_default_branch_ci() {
  if ! @defined "${CI:-}"; then
    return 0
  fi
  if @defined "${CI_COMMIT_BRANCH:-}" && [ "$CI_COMMIT_BRANCH" = "${CI_DEFAULT_BRANCH:-}" ]; then
    return 0
  fi
  fatal "release prepare: refusing to run off the default branch (CI_COMMIT_BRANCH='${CI_COMMIT_BRANCH:-}', CI_DEFAULT_BRANCH='${CI_DEFAULT_BRANCH:-}')."
  exit 1
}

: <<'PUB_FUN'
Lands the release for version $1 on the default branch, re-resolving and
retrying up to RELEASE_PUSH_ATTEMPTS times when concurrent merges move the
branch under the push. Records that a release was pushed for
releases__release_prepared.

Each attempt reads what the tip already holds (releases__tip_state) and does the rest:
nothing for a tagged version, the tag alone for a recorded one, the whole
release otherwise.

Returns 0 on a push or a clean no-op (the version is already tagged, or a
concurrent run already cut it); exits non-zero once the attempts are exhausted
or re-planning fails.
PUB_FUN
releases__cut_release() {
  __releases__cut_release__version="$1"
  __releases__cut_release__attempt=1

  while : ; do
    case "$(releases__tip_state "$__releases__cut_release__version")" in
      "$__releases__TIP_TAGGED")
        releases__skip_tagged "$__releases__cut_release__version"
        return 0
        ;;
      "$__releases__TIP_RECORDED") releases__tag_recorded_tip "$__releases__cut_release__version" ;;
      "$__releases__TIP_UNRELEASED") releases__cut_fresh_release "$__releases__cut_release__version" ;;
    esac

    if releases__push_release "$__releases__cut_release__version"; then
      @true __releases__PREPARED
      return 0
    fi

    if [ "$__releases__cut_release__attempt" -ge "$RELEASE_PUSH_ATTEMPTS" ]; then
      fatal "release prepare: push rejected after ${RELEASE_PUSH_ATTEMPTS} attempts; the default branch kept moving."
      exit 1
    fi

    __releases__cut_release__attempt=$((__releases__cut_release__attempt + 1))
    log "Push rejected; the default branch moved. Re-planning onto its new tip (attempt ${__releases__cut_release__attempt}/${RELEASE_PUSH_ATTEMPTS})."

    if ! __releases__cut_release__version="$(releases__resync_onto_default_branch "$__releases__cut_release__version")"; then
      error "Re-planning failed during push retry (see log above)."
      exit 1
    fi

    if ! @defined "$__releases__cut_release__version"; then
      log "A concurrent release already cut the pending version; nothing to push."
      return 0
    fi
  done
}

: <<'PUB_FUN'
The tagged arm: version $1 is already released, so there is nothing to do but
say so.
PUB_FUN
releases__skip_tagged() {
  log "Tag already exists for ${1}; skipping release."
}

: <<'PUB_FUN'
The recorded arm: the tip's manifest already holds version $1, so only the
ecosystems' files (if they lag) and the tag are missing. The tip is committed
only when their sync changed it.
PUB_FUN
releases__tag_recorded_tip() {
  log "The tip already records ${1}; tagging it."
  ecosystems__sync_version "$1"
  releases__commit_if_changed "$1"
  releases__tag_tip "$1"
}

: <<'PUB_FUN'
The unreleased arm: the usual release. Manifest and the ecosystems' files
synced, one commit naming the merge requests, and the tag on it.
PUB_FUN
releases__cut_fresh_release() {
  log "Releasing ${1}."
  releases__sync_manifest "$1"
  ecosystems__sync_version "$1"
  releases__commit_release "$1"
  releases__tag_tip "$1"
}

: <<'PUB_FUN'
Prints what the default branch's tip already holds for version $1:

  tagged      a tag records it, in either form; the release is done
  recorded    manifest.json holds it but no tag does
  unreleased  neither, which is the usual case after a merge

  releases__tip_state 1.2.3  ->  unreleased

Usage: releases__tip_state <version>
PUB_FUN
releases__tip_state() {
  __releases__tip_state__tag="$(versions__tag_for_version "$1")"
  if @defined "$__releases__tip_state__tag"; then
    println "$__releases__TIP_TAGGED"
    return 0
  fi
  if [ "$(releases__record__get_latest)" = "$1" ]; then
    println "$__releases__TIP_RECORDED"
    return 0
  fi

  println "$__releases__TIP_UNRELEASED"
}

: <<'PUB_FUN'
Map RELEASE_BUMP onto a cli/git-bump flag; "auto"/empty stays label-driven.
PUB_FUN
releases__bump_flag() {
  case "${RELEASE_BUMP:-auto}" in
    ""|auto) ;;
    *) printf -- '--%s' "$RELEASE_BUMP" ;;
  esac
}

: <<'PUB_FUN'
Echoes the version to release on stdout, or nothing when no bump is due.

  releases__plan_version [fresh]

A forced RELEASE_BUMP (major/minor/...) drives cli/git-bump directly with that
bump type. Otherwise the version is planned from the labels of the code reviews
merged since the last tag: in CI the first pass trusts the PLANNED_VERSION an
earlier job computed when one is set, while "fresh" -- used on a push retry,
after the branch moved -- always re-plans inline via cli/plan-version, so a
concurrent release that already consumed those labels collapses to an empty
result rather than cutting a duplicate. The picked version is validated
against existing tags via cli/git-bump --from-plan.

Returns non-zero only on a hard planning failure (a contradictory-labels exit or
an invalid picked version), which releases__release_prepare surfaces as a red pipeline.
PUB_FUN
releases__plan_version() {
  __releases__plan_version__mode="${1:-}"
  __releases__plan_version__flag="$(releases__bump_flag)"

  if @defined "$__releases__plan_version__flag"; then
    # Intentional word-split: a single --<bump> flag.
    # shellcheck disable=SC2086
    "$SHELLOPS_DIR/cli/git-bump" --dry-run $__releases__plan_version__flag
    return
  fi

  if @defined "${CI:-}" && [ "$__releases__plan_version__mode" != fresh ] && @defined "${PLANNED_VERSION:-}"; then
    __releases__plan_version__picked="$PLANNED_VERSION"
  else
    __releases__plan_version__picked="$("$SHELLOPS_DIR/cli/plan-version")" || return 1
  fi

  if ! @defined "$__releases__plan_version__picked"; then
    return 0
  fi

  "$SHELLOPS_DIR/cli/git-bump" --dry-run --from-plan "$__releases__plan_version__picked"
}

: <<'PUB_FUN'
Re-resolves the version to release against the current tip of the default
branch, for use after a rejected push. Echoes that version, or nothing when a
concurrent release has already cut it. Non-zero on a fetch/reset or planning
failure.
PUB_FUN
releases__resync_onto_default_branch() {
  git tag -d "$1" >/dev/null 2>&1 || true
  git fetch --quiet --tags origin "$(releases__release_line)" || return 1
  git reset --hard --quiet FETCH_HEAD || return 1
  releases__plan_version fresh
}

releases__sync_forge_labels() {
  "$SHELLOPS_DIR/action" forge sync-labels
}

releases__sync_manifest() {
  "$SHELLOPS_DIR/cli/sync-manifest" "$1"
}

: <<'PUB_FUN'
Prints the references of the merge requests this release covers, in the
forge's own spelling, comma-separated: every code review merged into the
default branch since the nearest tag the checkout reaches, which on the trunk
is the last release cut from it. A release above dev sits on a record off the
trunk (ADR 000044) and does not bound the window.

  releases__release_refs  ->  !12, !15

Usage: releases__release_refs
PUB_FUN
releases__release_refs() {
  __releases__release_refs__since="$(versions__nearest_tag_date)"
  __releases__release_refs__branch="$(forge__default_branch)"
  __releases__release_refs__reviews="$(forge__merged_reviews_since "$__releases__release_refs__since" "$__releases__release_refs__branch")"
  @pluck __releases__release_refs__numbers "$__releases__release_refs__reviews" '.iid'
  @map __releases__release_refs__refs __releases__review_ref "$__releases__release_refs__numbers"

  @join __releases__release_refs__out "$__releases__release_refs__refs" ", "
  println "$__releases__release_refs__out"
}

__releases__review_ref() {
  @unwrap __releases__review_ref__unwrap_1 "$1"
  forge__review_ref "$__releases__review_ref__unwrap_1"
}

: <<'PUB_FUN'
Prints the release commit's message: the version, the merge requests it
covers when there are any, and the trailer that marks the commit as the
record of that version, which a reader of the line tells the record by
(lib/releases/record/commit.sh). The message asks the forge for nothing: the tag
points at this commit, so a skip marker here would hold back the tag's run
along with the branch's. Keeping the branch push quiet is releases__push_release_commit's.

  releases__release_commit_message 1.2.3  ->  chore: release 1.2.3 (!12, !15)
                                    <blank line>
                                    Release-Record: 1.2.3

Usage: releases__release_commit_message <version>
PUB_FUN
releases__release_commit_message() {
  __releases__release_commit_message__subject="$(releases__prepare__commit_subject "$1")"
  __releases__release_commit_message__trailer="$(releases__record__trailer "$1")"

  printf '%s\n\n%s\n' "$__releases__release_commit_message__subject" "$__releases__release_commit_message__trailer"
}

: <<'PUB_FUN'
Prints the release commit's subject: the version, and the merge requests it
covers when there are any.

  releases__prepare__commit_subject 1.2.3  ->  chore: release 1.2.3 (!12, !15)

Usage: releases__prepare__commit_subject <version>
PUB_FUN
releases__prepare__commit_subject() {
  __releases__prepare__commit_subject__refs="$(releases__release_refs)"
  if ! @defined "$__releases__prepare__commit_subject__refs"; then
    printf 'chore: release %s\n' "$1"
    return 0
  fi

  printf 'chore: release %s (%s)\n' "$1" "$__releases__prepare__commit_subject__refs"
}

: <<'PUB_FUN'
Prints true when the release files differ from the tip, which is to say the
sync wrote something the tip does not already record.
PUB_FUN
releases__release_files_changed() {
  __releases__release_files_changed__files="$(releases__release_files)"

  @fails __releases__release_files_changed__out @apply git diff --quiet HEAD -- "$__releases__release_files_changed__files"
  println "$__releases__release_files_changed__out"
}

: <<'PUB_FUN'
Commits the synced files as the release of version $1: exactly the release
files, so whatever the job left untracked in the tree stays out.
PUB_FUN
releases__commit_release() {
  __releases__commit_release__files="$(releases__release_files)"
  __releases__commit_release__message="$(releases__release_commit_message "$1")"

  @apply \
    "$SHELLOPS_DIR/cli/git-commit" \
    -m "$__releases__commit_release__message" \
    -- \
    "$__releases__commit_release__files"
}

: <<'PUB_FUN'
Commits the release files for version $1 when the tip does not already record
them; a tip that does is left as it is.
PUB_FUN
releases__commit_if_changed() {
  if @is_true "$(releases__release_files_changed)"; then
    releases__commit_release "$1"
  fi
}

: <<'PUB_FUN'
Tags the tip with version $1 itself: bare, the same string manifest.json
holds. Readers accept either form (versions__tag_for_version), so a repository with
v-prefixed history keeps resolving.
PUB_FUN
releases__tag_tip() {
  git tag -a "$1" -m "$1"
}

: <<'PUB_FUN'
Prints the branch a release lands on: the one the pipeline names, and the
branch origin points its HEAD at when no pipeline does, so a release cut by
hand lands where one cut in CI does.

  releases__release_line  ->  main

Usage: releases__release_line
PUB_FUN
releases__release_line() {
  println "${CI_DEFAULT_BRANCH:-$(git__default_branch)}"
}

: <<'PUB_FUN'
Pushes the release: the commit to the default branch first, then the tag $1
on its own. Non-zero when either push is rejected. A rejected branch push
pushes no tag, so no orphan tag is left behind; a commit that landed without
its tag is the recorded tip the next attempt tags (releases__tip_state).
PUB_FUN
releases__push_release() {
  releases__push_release_commit || return 1
  releases__push_release_tag "$1"
}

: <<'PUB_FUN'
Pushes the release commit to the default branch, asking the forge to run
nothing for it: the commit only records a version, and the run that matters
is the tag's. The request travels with this push alone, as the options
forge__no_run_push_options names, so it reaches the branch and never the tag.
Non-zero when the push is rejected.
PUB_FUN
releases__push_release_commit() {
  __releases__push_release_commit__options="$(forge__no_run_push_options)"
  @map __releases__push_release_commit__flags __releases__push_option_flag "$__releases__push_release_commit__options"

  @apply git push origin "HEAD:$(releases__release_line)" "$__releases__push_release_commit__flags"
}

: <<'FUN'
@map callback: the git flag carrying the wrapped push option.

  __releases__push_option_flag '"ci.skip"'  ->  --push-option=ci.skip
FUN
__releases__push_option_flag() {
  @unwrap __releases__push_option_flag__unwrap_2 "$1"
  printf -- '--push-option=%s\n' "$__releases__push_option_flag__unwrap_2"
}

: <<'PUB_FUN'
Pushes the tag $1 on its own, so the forge runs the tag's pipeline. Non-zero
when the push is rejected.
PUB_FUN
releases__push_release_tag() {
  git push origin "$1"
}
