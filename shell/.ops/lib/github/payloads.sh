#!/bin/sh

:<<'FRAGMENT'
The bodies GitHub's review and label calls send.
FRAGMENT

:<<'FUN'
A label as GitHub takes it: name, color and description, the color without
the leading hash the label sets carry and kept a string where its digits would
read as a number, and an empty field left out so an edit never blanks what it
was not given. GitHub renames through new_name, so on an edit the name travels
under that key.

  __github__label_body '{"name":"type/fix","color":"#447755"}'  ->  {"name":"type/fix","color":"447755"}
FUN
__github__label_body() {
  @let "$1" __github__label_body__ name color description
  __github__label_body__color="${__github__label_body__color#\#}"
  __github__label_body__name_key="${2:-name}"

  @encode_string __github__label_body__encode_string_1 "$__github__label_body__color"
  @obj __github__label_body__obj_2 \
    ".$__github__label_body__name_key" "$__github__label_body__name" \
    '.color'       "$__github__label_body__encode_string_1" \
    '.description' "$__github__label_body__description"
  @filter __github__label_body__given "$__github__label_body__obj_2" forge__base__member_is_set
  @dump __github__label_body__out "$__github__label_body__given"
  __github__label_body__status=$?
  println "$__github__label_body__out"
  @unlet __github__label_body__ name color description
  return "$__github__label_body__status"
}

:<<'FUN'
The body that opens a pull request: title, head, base and body, an empty one
left out. Assignees and labels are not GitHub's to take here; they go to the
issue afterwards (__github__issue_update_body).
FUN
__github__pull_request_body() {
  @pick __github__pull_request_body__fields "$1" title head base body
  @filter __github__pull_request_body__given "$__github__pull_request_body__fields" forge__base__member_is_set
  @dump __github__pull_request_body__out "$__github__pull_request_body__given"
  println "$__github__pull_request_body__out"
}

:<<'FUN'
The assignees and labels a caller asked for on a new pull request, as the
issue update GitHub takes them through; empty when it asked for none.
FUN
__github__issue_update_body() {
  @pick __github__issue_update_body__fields "$1" assignees labels
  @filter __github__issue_update_body__given "$__github__issue_update_body__fields" __github__member_names_something
  @dump __github__issue_update_body__out "$__github__issue_update_body__given"
  println "$__github__issue_update_body__out"
}

:<<'FUN'
A predicate for @filter: answers true in the variable $1 when the member $3
names something, and false when it is a null, the empty string or an empty
list.
FUN
__github__member_names_something() {
  @typeof __github__member_names_something__type "$3"
  if [ "$__github__member_names_something__type" = array ] && @empty "$3"; then
    @false "$1"
    return 0
  fi

  forge__base__member_is_set "$@"
}

:<<'FUN'
The title and body a caller asked to change, an empty one left out so a PATCH
never blanks a field it was not given.
FUN
__github__pull_request_update_body() {
  @pick __github__pull_request_update_body__fields "$1" title body
  @filter __github__pull_request_update_body__given "$__github__pull_request_update_body__fields" forge__base__member_is_set
  @dump __github__pull_request_update_body__out "$__github__pull_request_update_body__given"
  println "$__github__pull_request_update_body__out"
}

:<<'FUN'
The name of the label .label_id names, read from the repository's labels,
since GitHub addresses a label by name. Fails when no label carries the id.

Usage: __github__label_name_of "$label_options"
FUN
__github__label_name_of() {
  @let "$1" __github__label_name_of__ label_id owner repo
  __github__label_name_of__labels="$(github_list_labels "$1")" || return 1
  @filter __github__label_name_of__carrying "$__github__label_name_of__labels" silt__text_is .id "$__github__label_name_of__label_id"
  @first __github__label_name_of__label "$__github__label_name_of__carrying"
  @get __github__label_name_of__name "$__github__label_name_of__label" '.name' ''
  if ! @defined "$__github__label_name_of__name"; then
    error "No label with id $__github__label_name_of__label_id on $__github__label_name_of__owner/$__github__label_name_of__repo"
    return 1
  fi

  @unlet __github__label_name_of__ label_id owner repo
  println "$__github__label_name_of__name"
}

:<<'FUN'
Removes one label from a pull request; @foreach hands the name over still
JSON-encoded.

Usage: __github__remove_review_label '"role/ktlo"' "$options" "$http_opts"
FUN
__github__remove_review_label() {
  @unwrap __github__remove_review_label__unwrap_3 "$1"
  @set __github__remove_review_label__options "$2" '.label_name' "$__github__remove_review_label__unwrap_3"
  http__delete \
    "$(__github__render_endpoint "$__github__ISSUE_LABEL_ENDPOINT" "$__github__remove_review_label__options")" \
    "$3" > /dev/null
}
