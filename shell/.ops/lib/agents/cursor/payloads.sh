#!/bin/sh

:<<'FRAGMENT'
What the cursor adaptor sends and what it hands back: the check of the
options' cursor block against options.schema.json beside this file, the
create-agent body a run describes, the env block a run asks for, and the
review URLs a run record carries.
FRAGMENT

__agents__cursor__payloads__OPTIONS_SCHEMA="$SHELLOPS_DIR/lib/agents/cursor/options.schema.json"

:<<'FUN'
Checks the cursor block of the run options $1 against the adaptor's options
schema, failing on a key cursor does not understand rather than dropping it.
FUN
__agents__cursor__payloads__check_options() {
  @obj __agents__cursor__payloads__check_options__obj_1
  @get __agents__cursor__payloads__check_options__block "$1" '.cursor' "$__agents__cursor__payloads__check_options__obj_1"
  if ! @validate "$__agents__cursor__payloads__check_options__block" "$__agents__cursor__payloads__OPTIONS_SCHEMA" >/dev/null; then
    error "cursor: the options' .cursor block does not fit $__agents__cursor__payloads__OPTIONS_SCHEMA"
    return 1
  fi
}

:<<'FUN'
Prints the create-agent body the run options $1 and the prompt $2 describe:
the prompt, the model when one is named, the display name when one is given,
the repository and its starting ref when the run has one, and the execution
environment when it is not Cursor's default.

  __agents__cursor__payloads__create_body "$(agents__new_run_options)" "Add a README"
  ->  {"prompt":{"text":"Add a README"},"autoCreatePR":false}
FUN
__agents__cursor__payloads__create_body() {
  @option __agents__cursor__payloads__create_body__option_2 "$1" 'open_review' false
  @obj __agents__cursor__payloads__create_body__body \
    '.prompt.text'  "$2" \
    '.autoCreatePR' "$__agents__cursor__payloads__create_body__option_2"
  @option __agents__cursor__payloads__create_body__model "$1" 'model' ''
  if @defined "$__agents__cursor__payloads__create_body__model"; then
    @set __agents__cursor__payloads__create_body__body "$__agents__cursor__payloads__create_body__body" '.model.id' "$__agents__cursor__payloads__create_body__model"
  fi
  @option __agents__cursor__payloads__create_body__name "$1" 'name' ''
  if @defined "$__agents__cursor__payloads__create_body__name"; then
    @set __agents__cursor__payloads__create_body__body "$__agents__cursor__payloads__create_body__body" '.name' "$__agents__cursor__payloads__create_body__name"
  fi
  @option __agents__cursor__payloads__create_body__repo "$1" 'repo' ''
  if @defined "$__agents__cursor__payloads__create_body__repo"; then
    @option __agents__cursor__payloads__create_body__option_3 "$1" 'ref' main
    @obj __agents__cursor__payloads__create_body__obj_4 '.url' "$__agents__cursor__payloads__create_body__repo" '.startingRef' "$__agents__cursor__payloads__create_body__option_3"
    @arr __agents__cursor__payloads__create_body__repos "$__agents__cursor__payloads__create_body__obj_4"
    @set __agents__cursor__payloads__create_body__body "$__agents__cursor__payloads__create_body__body" '.repos' "$__agents__cursor__payloads__create_body__repos"
  fi
  __agents__cursor__payloads__create_body__env="$(__agents__cursor__payloads__env "$1")"
  if @defined "$__agents__cursor__payloads__create_body__env"; then
    @set __agents__cursor__payloads__create_body__body "$__agents__cursor__payloads__create_body__body" '.env' "$__agents__cursor__payloads__create_body__env"
  fi
  println "$__agents__cursor__payloads__create_body__body"
}

:<<'FUN'
Prints the env struct the run options $1 ask for, nothing when they ask for
Cursor's default: a type other than cloud, or a named environment.

  __agents__cursor__payloads__env '{"cursor":{"env":{"type":"pool","name":"gpu"}}}'  ->  {"type":"pool","name":"gpu"}
FUN
__agents__cursor__payloads__env() {
  @get __agents__cursor__payloads__env__type "$1" '.cursor.env.type' cloud
  @get __agents__cursor__payloads__env__name "$1" '.cursor.env.name' ''
  if [ "$__agents__cursor__payloads__env__type" = cloud ] && ! @defined "$__agents__cursor__payloads__env__name"; then
    return 0
  fi
  if @defined "$__agents__cursor__payloads__env__name"; then
    @obj __agents__cursor__payloads__env__out '.type' "$__agents__cursor__payloads__env__type" '.name' "$__agents__cursor__payloads__env__name"
    println "$__agents__cursor__payloads__env__out"
  else
    @obj __agents__cursor__payloads__env__out '.type' "$__agents__cursor__payloads__env__type"
    println "$__agents__cursor__payloads__env__out"
  fi
}

:<<'FUN'
Prints the review URLs the run record $1 carries, as an array: one per
pushed branch that opened one.

  __agents__cursor__payloads__reviews '{"git":{"branches":[{"prUrl":"https://x/-/merge_requests/7"},{"branch":"c"}]}}'
  ->  ["https://x/-/merge_requests/7"]
FUN
__agents__cursor__payloads__reviews() {
  @arr __agents__cursor__payloads__reviews__arr_5
  @get __agents__cursor__payloads__reviews__branches "$1" '.git.branches' "$__agents__cursor__payloads__reviews__arr_5"
  @map __agents__cursor__payloads__reviews__map_6 __agents__cursor__payloads__branch_review "$__agents__cursor__payloads__reviews__branches"
  @filter __agents__cursor__payloads__reviews__out "$__agents__cursor__payloads__reviews__map_6" silt__text_is_not . ''
  println "$__agents__cursor__payloads__reviews__out"
}

:<<'FUN'
Prints the review URL the pushed branch $1 opened, wrapped; wrapped empty
when it opened none.
FUN
__agents__cursor__payloads__branch_review() {
  @get __agents__cursor__payloads__branch_review__get_7 "$1" '.prUrl' ''
  @wrap __agents__cursor__payloads__branch_review__out "$__agents__cursor__payloads__branch_review__get_7"
  println "$__agents__cursor__payloads__branch_review__out"
}
