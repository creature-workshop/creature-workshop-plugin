#!/bin/sh

:<<'FRAGMENT'
Label payloads for GitLab: the body a label is created or edited with, and the add/remove body a review's labels change through.
FRAGMENT

__gitlab__normalize_label_body() {
  @let "$1" __gitlab__normalize_label_body__ name color description

  if @defined "$__gitlab__normalize_label_body__color"; then
    case "$__gitlab__normalize_label_body__color" in
      "#"*) ;;
      *) __gitlab__normalize_label_body__color="#${__gitlab__normalize_label_body__color}" ;;
    esac
  fi

  @obj __gitlab__normalize_label_body__payload \
    '.name'        "$__gitlab__normalize_label_body__name" \
    '.color'       "$__gitlab__normalize_label_body__color" \
    '.description' "$__gitlab__normalize_label_body__description"

  # A field with no value is left out, so an edit never blanks a field it was not given.
  @filter __gitlab__normalize_label_body__given "$__gitlab__normalize_label_body__payload" forge__base__member_is_set
  @dump __gitlab__normalize_label_body__out "$__gitlab__normalize_label_body__given"
  println "$__gitlab__normalize_label_body__out"
  @unlet __gitlab__normalize_label_body__ name color description
}

:<<'FUN'
The body of a label change: add_labels and remove_labels as the comma-separated
lists GitLab reads, each present only when it names something.

  __gitlab__label_change_body '["role/platform"]' '[]'  ->  {"add_labels":"role/platform"}
FUN
__gitlab__label_change_body() {
  @obj __gitlab__label_change_body__out
  @join __gitlab__label_change_body__add "$1" ","
  @join __gitlab__label_change_body__remove "$2" ","

  if @defined "$__gitlab__label_change_body__add"; then
    @set __gitlab__label_change_body__out "$__gitlab__label_change_body__out" '.add_labels' "$__gitlab__label_change_body__add"
  fi
  if @defined "$__gitlab__label_change_body__remove"; then
    @set __gitlab__label_change_body__out "$__gitlab__label_change_body__out" '.remove_labels' "$__gitlab__label_change_body__remove"
  fi

  println "$__gitlab__label_change_body__out"
}

:<<'CONST'
The scheduler's landing mark: the label it sets on a merge request before it
creates the landing run. The pipeline rules under .gitlab-ci read the same
label, so a job's rules and the stale guard agree on which run is landing.
CONST
__gitlab__LANDING_LABEL="scheduler/next-merge"

:<<'FUN'
@any predicate: succeeds when the wrapped label $1 is the landing mark.

  @any __gitlab__is_landing_label '["type/fix","scheduler/next-merge"]'  ->  true
FUN
__gitlab__is_landing_label() {
  @unwrap __gitlab__is_landing_label__unwrap_1 "$1"
  [ "$__gitlab__is_landing_label__unwrap_1" = "$__gitlab__LANDING_LABEL" ]
}
