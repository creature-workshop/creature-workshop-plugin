#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/versions/api.sh" \
  "$SHELLOPS_DIR/lib/manifest/api.sh" \
  "$SHELLOPS_DIR/lib/releases/record/api.sh" \
  "$SHELLOPS_DIR/lib/bump/labels.sh" \
  "$SHELLOPS_DIR/lib/bump/version.sh" \
  "$SHELLOPS_DIR/lib/bump/level.sh" \
  "$SHELLOPS_DIR/lib/bump/options.sh" \
  "$SHELLOPS_DIR/lib/bump/tags.sh" \
  "$SHELLOPS_DIR/lib/bump/dev_channel.sh" \
  "$SHELLOPS_DIR/lib/bump/auto_promote.sh" \
  "$SHELLOPS_DIR/lib/bump/release.sh" \
  "$SHELLOPS_DIR/lib/bump/prerelease.sh" \
  "$SHELLOPS_DIR/lib/bump/next_version.sh" \
  "$SHELLOPS_DIR/lib/bump/plan.sh"

: <<'DOC'
API for planning the next semver version from PR labels, git tags, and the
project manifest. A caller imports this file and reaches bump__plan_bump,
bump__compute_next_version, bump__aggregate_code_review_labels, bump__validate_meta_labels,
bump__default_channel, bump__auto_promote_until, bump__rung_is_automatic, bump__use_project_manifest and
bump__check_release_safety without naming the module any one of them lives in; the modules beside this file reach each
other the same way, so none of them imports another.

POSIX sh-clean (no local/[[ ]]/(( ))/arrays/namerefs): parsed versions flow
through the structs API as immutable struct strings rather than bash
associative arrays. Mutating helpers take a version struct and echo a new one;
readers take a struct and read its fields through the structs API -- mirroring
how lib/versions/api.sh models parsed versions.
DOC
