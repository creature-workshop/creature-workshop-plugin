#!/bin/sh

:<<'FRAGMENT'
What a merge's labels say, before any version arithmetic reads them: whether a
label is present, the union of the labels across every merged code review, and
whether the set contradicts itself.

Its own module because nothing here looks at a version. The union and the
contradiction check also have to agree on counting distinct labels, so a
release planned from many merged reviews cannot false-trip the check.
FRAGMENT

: <<'PUB_FUN'
Validates that no contradictory meta labels are present.

Returns 0 on success, 1 on conflict with a message describing the issue.

Usage: bump__validate_meta_labels "$labels"
PUB_FUN
bump__validate_meta_labels() {
  __bump__validate_meta_labels__labels="$1"
  __bump__validate_meta_labels__count=0
  __bump__validate_meta_labels__found=""

  if @is_true "$(__bump__has_label "$__bump__validate_meta_labels__labels" "meta/experimental")"; then
    __bump__validate_meta_labels__found="${__bump__validate_meta_labels__found:+$__bump__validate_meta_labels__found,}meta/experimental"
    __bump__validate_meta_labels__count=$((__bump__validate_meta_labels__count + 1))
  fi
  if @is_true "$(__bump__has_label "$__bump__validate_meta_labels__labels" "meta/promote")"; then
    __bump__validate_meta_labels__found="${__bump__validate_meta_labels__found:+$__bump__validate_meta_labels__found,}meta/promote"
    __bump__validate_meta_labels__count=$((__bump__validate_meta_labels__count + 1))
  fi
  if @is_true "$(__bump__has_label "$__bump__validate_meta_labels__labels" "meta/release")"; then
    __bump__validate_meta_labels__found="${__bump__validate_meta_labels__found:+$__bump__validate_meta_labels__found,}meta/release"
    __bump__validate_meta_labels__count=$((__bump__validate_meta_labels__count + 1))
  fi

  if [ "$__bump__validate_meta_labels__count" -gt 1 ]; then
    error "Contradictory meta labels: $__bump__validate_meta_labels__found. Only one version-transition label is allowed per PR."
    return 1
  fi
}

: <<'PUB_FUN'
Folds the label arrays of every merged code review into a single
de-duplicated JSON array.

Pure function: no side effects, no API calls. Takes a JSON array of
merged-code-review records -- each shaped {iid, merged_at, labels:[...]}, where
.labels is the array of label name strings -- unions every record's labels and
removes duplicates, yielding one label array.

The union + de-dup matches how the bump logic reads labels:
__bump__infer_bump_level is presence-based (a single max bump), so N feature
code reviews collapse to one minor, and a label repeated across code reviews
(e.g. meta/promote on two) does not false-trip bump__validate_meta_labels, which
counts distinct meta labels.

Usage: bump__aggregate_code_review_labels "$merged_code_reviews_json"  # -> ["type/feature","crit/breaking"]
PUB_FUN
bump__aggregate_code_review_labels() {
  @pluck __bump__aggregate_code_review_labels__label_lists "$1" '.labels'
  @arr __bump__aggregate_code_review_labels__arr_1
  @reduce __bump__aggregate_code_review_labels__union __bump__concat_labels "$__bump__aggregate_code_review_labels__label_lists" "$__bump__aggregate_code_review_labels__arr_1"
  @unique __bump__aggregate_code_review_labels__out "$__bump__aggregate_code_review_labels__union"
  println "$__bump__aggregate_code_review_labels__out"
}

: <<'FUN'
@reduce callback: appends one code review's label array onto the running union.
FUN
__bump__concat_labels() {
  @concat __bump__concat_labels__out "$1" "$2"
  println "$__bump__concat_labels__out"
}

:<<'FUN'
Prints the struct boolean for whether the label name $2 is an element of the
JSON label array $1.

Usage: if @is_true "$(__bump__has_label "$labels" "meta/release")"; then ... fi
FUN
__bump__has_label() {
  @find __bump__has_label__find_2 __bump__label_eq "$1" "$2"
  @succeeds __bump__has_label__out @defined "$__bump__has_label__find_2"
  println "$__bump__has_label__out"
}

:<<'FUN'
@find predicate: true when a label element equals the target name.

  $1 element (wrapped)   $2 target label
FUN
__bump__label_eq() {
  @unwrap __bump__label_eq__unwrap_3 "$1"
  [ "$__bump__label_eq__unwrap_3" = "$2" ]
}

:<<'FUN'
Prints the struct boolean for whether any of the label names $2.. is an element
of the JSON label array $1.

Usage: if @is_true "$(__bump__has_any_label "$labels" "crit/breaking" "crit/removal")"; then ... fi
FUN
__bump__has_any_label() {
  __bump__has_any_label__labels="$1"
  shift
  for __bump__has_any_label__label in "$@"; do
    if @is_true "$(__bump__has_label "$__bump__has_any_label__labels" "$__bump__has_any_label__label")"; then
      @true __bump__has_any_label__out
      println "$__bump__has_any_label__out"
      return
    fi
  done
  @false __bump__has_any_label__out
  println "$__bump__has_any_label__out"
}
