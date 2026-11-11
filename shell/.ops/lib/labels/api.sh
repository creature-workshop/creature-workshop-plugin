#!/bin/sh

:<<'MODULE'
API for label taxonomy: merging org-wide base labels with per-repo extensions.

Produces a combined label set from two sources:
  1. Base definitions (schema/labels.base.json) -- org-wide Forgejo label categories
  2. Repo extensions (manifest.json .labels)   -- per-repo items and net-new categories

Repo categories use one of two forms:
  Flat form:  {"cli": "CLI tools", "lib": "Libraries"}
  Full form:  {"color": "#4477aa", "items": {"cli": "CLI tools"}}

Flat form extends an existing base category. Full form is for net-new categories
that need a color. The forms are distinguished by checking whether .items is an object.

Merge rules:
  - Base color is authoritative (repo cannot override it)
  - Items are unioned; repo descriptions win on conflict
  - Net-new categories without a color are rejected

Accessed via manifest__get("labels"), which delegates to labels__merged_labels().

Sync support:
  labels__flatten_labels()  -- converts the merged tree into a flat [{name, color, description}] array
  labels__diff_labels()     -- compares desired (flat) vs actual (Forgejo) and produces create/update/archive lists
MODULE

import "$SHELLOPS_DIR/lib/areas/api.sh"
import "$SHELLOPS_DIR/lib/self/config.sh"

__labels__BASE_FILE="$SHELLOPS_DIR/schema/labels.base.json"

:<<'PUB_FUN'
Returns the fully merged label set as a JSON object.

When the manifest defines a "testing" config, computed area labels are injected
into the repo labels before merging. Computed areas are unioned with any
manually declared area items (computed wins on conflict).

Usage: labels__merged_labels
PUB_FUN
labels__merged_labels() {
  __labels__merged_labels__base="$(__labels__load_base)" || return 1
  __labels__merged_labels__repo_labels="$(__labels__load_repo_labels)"
  __labels__merged_labels__repo_labels="$(__labels__inject_computed_areas "$__labels__merged_labels__repo_labels")"

  __labels__validate "$__labels__merged_labels__base" "$__labels__merged_labels__repo_labels" || return 1
  __labels__merge "$__labels__merged_labels__base" "$__labels__merged_labels__repo_labels"
}

__labels__inject_computed_areas() {
  __labels__inject_computed_areas__repo_labels="$1"

  if @is_false "$(areas__has_areas_config)"; then
    echo "$__labels__inject_computed_areas__repo_labels"
    return
  fi

  __labels__inject_computed_areas__config="$(areas__load_areas_config)"
  __labels__inject_computed_areas__canonical_areas="$(areas__compute_areas "$__labels__inject_computed_areas__config")" || {
    echo "$__labels__inject_computed_areas__repo_labels"
    return
  }
  __labels__inject_computed_areas__label_items="$(areas__to_label_items "$__labels__inject_computed_areas__canonical_areas")"

  @obj __labels__inject_computed_areas__obj_1
  @get __labels__inject_computed_areas__existing_area "$__labels__inject_computed_areas__repo_labels" '.area' "$__labels__inject_computed_areas__obj_1"
  @merge __labels__inject_computed_areas__merged_area "$__labels__inject_computed_areas__existing_area" "$__labels__inject_computed_areas__label_items"

  @set __labels__inject_computed_areas__out "$__labels__inject_computed_areas__repo_labels" '.area' "$__labels__inject_computed_areas__merged_area"
  println "$__labels__inject_computed_areas__out"
}

__labels__load_base() {
  if [ ! -f "$__labels__BASE_FILE" ]; then
    error "Base label file not found: $__labels__BASE_FILE"
    return 1
  fi
  cat "$__labels__BASE_FILE"
}

__labels__load_repo_labels() {
  __labels__load_repo_labels__manifest="$(self__config__load manifest)"
  @obj __labels__load_repo_labels__obj_2
  @get __labels__load_repo_labels__out "$__labels__load_repo_labels__manifest" '.labels' "$__labels__load_repo_labels__obj_2"
  println "$__labels__load_repo_labels__out"
}

__labels__validate() {
  __labels__validate__base="$1"
  __labels__validate__repo_labels="$2"

  @entries __labels__validate__entries "$__labels__validate__repo_labels"
  @arr __labels__validate__arr_3
  @reduce __labels__validate__missing __labels__find_missing_colors "$__labels__validate__entries" "$__labels__validate__arr_3" "$__labels__validate__base"
  @len __labels__validate__count "$__labels__validate__missing"

  if [ "$__labels__validate__count" -gt 0 ]; then
    @join __labels__validate__join_4 "$__labels__validate__missing" ", "
    error "Label categories not in base and missing color: $__labels__validate__join_4"
    return 1
  fi
}

__labels__find_missing_colors() {
  __labels__find_missing_colors__acc="$1"
  __labels__find_missing_colors__entry="$2"
  __labels__find_missing_colors__base="$3"

  @let "$__labels__find_missing_colors__entry" __labels__find_missing_colors__ key value
  @get __labels__find_missing_colors__base_cat "$__labels__find_missing_colors__base" ".\"$__labels__find_missing_colors__key\""

  if @defined "$__labels__find_missing_colors__base_cat"; then
    echo "$__labels__find_missing_colors__acc"
    return
  fi

  if @typeof __labels__find_missing_colors__typeof_5 "$__labels__find_missing_colors__value" '.items'; [ "$__labels__find_missing_colors__typeof_5" != "object" ] ||
  @typeof __labels__find_missing_colors__typeof_6 "$__labels__find_missing_colors__value" '.color'
  [ "$__labels__find_missing_colors__typeof_6" != "string" ]; then
    @push __labels__find_missing_colors__out "$__labels__find_missing_colors__acc" "\"$__labels__find_missing_colors__key\""
    println "$__labels__find_missing_colors__out"
    return
  fi

  echo "$__labels__find_missing_colors__acc"
  @unlet __labels__find_missing_colors__ key value
}

__labels__merge() {
  __labels__merge__base="$1"
  __labels__merge__repo_labels="$2"

  @entries __labels__merge__entries "$__labels__merge__repo_labels"
  @reduce __labels__merge__out __labels__merge_category "$__labels__merge__entries" "$__labels__merge__base"
  println "$__labels__merge__out"
}

:<<'FUN'
@reduce callback. Normalizes each repo category (flat vs full form),
then either merges items into an existing base category or adds a net-new one.
FUN
__labels__merge_category() {
  __labels__merge_category__acc="$1"
  __labels__merge_category__entry="$2"

  @let "$__labels__merge_category__entry" __labels__merge_category__ key value

  if @typeof __labels__merge_category__typeof_7 "$__labels__merge_category__value" '.items'; [ "$__labels__merge_category__typeof_7" = "object" ]; then
    @let "$__labels__merge_category__value" __labels__merge_category__ items color
  else
    __labels__merge_category__items="$__labels__merge_category__value"
    __labels__merge_category__color=""
  fi

  @get __labels__merge_category__existing "$__labels__merge_category__acc" ".\"$__labels__merge_category__key\""

  if @defined "$__labels__merge_category__existing"; then
    __labels__merge_existing "$__labels__merge_category__acc" "$__labels__merge_category__key" "$__labels__merge_category__existing" "$__labels__merge_category__items"
  else
    __labels__add_new "$__labels__merge_category__acc" "$__labels__merge_category__key" "$__labels__merge_category__color" "$__labels__merge_category__items"
  fi
  __labels__merge_category__status=$?
  @unlet __labels__merge_category__ key value
  @unlet __labels__merge_category__ items color
  return "$__labels__merge_category__status"
}

__labels__merge_existing() {
  __labels__merge_existing__acc="$1"
  __labels__merge_existing__key="$2"
  __labels__merge_existing__existing="$3"
  __labels__merge_existing__items="$4"

  @get __labels__merge_existing__existing_items "$__labels__merge_existing__existing" '.items'
  @merge __labels__merge_existing__merged_items "$__labels__merge_existing__existing_items" "$__labels__merge_existing__items"

  @set __labels__merge_existing__out "$__labels__merge_existing__acc" ".\"$__labels__merge_existing__key\".items" "$__labels__merge_existing__merged_items"
  println "$__labels__merge_existing__out"
}

__labels__add_new() {
  __labels__add_new__acc="$1"
  __labels__add_new__key="$2"
  __labels__add_new__color="$3"
  __labels__add_new__items="$4"

  @obj __labels__add_new__new_cat '.color' "$__labels__add_new__color" '.items' "$__labels__add_new__items"
  @set __labels__add_new__out "$__labels__add_new__acc" ".\"$__labels__add_new__key\"" "$__labels__add_new__new_cat"
  println "$__labels__add_new__out"
}

:<<'PUB_FUN'
Converts a merged label tree into a flat array of label objects.

Each object has {name, color, description} where name is "category/item".

Usage: labels__flatten_labels "$merged_labels_json"
PUB_FUN
labels__flatten_labels() {
  @run_awk __labels__flatten_labels__out "$SHELLOPS_DIR/lib/labels/flatten_labels.awk" "$1" || return 1
  println "$__labels__flatten_labels__out"
}

:<<'PUB_FUN'
Compares desired labels against actual Forgejo labels.

Returns a JSON object with three arrays: {create, update, archive}.
  create:  labels in desired but not in actual
  update:  labels in both but with drifted color or description
  archive: labels in actual but not in desired (and not already archived)

Forgejo returns colors without '#'; desired colors include '#'.
Normalization is handled internally.

Usage: labels__diff_labels "$desired_flat" "$actual_forgejo"
PUB_FUN
labels__diff_labels() {
  @run_awk __labels__diff_labels__out "$SHELLOPS_DIR/lib/labels/diff_labels.awk" "$1" --with "$2" || return 1
  println "$__labels__diff_labels__out"
}
