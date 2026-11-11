#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/graphql/api.sh" \
  "$SHELLOPS_DIR/lib/linear/api.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'MODULE'
Linear's email intake addresses: the address Linear generates for a team,
with the custom address that forwards to it, so that a mail to the custom
address becomes an issue of the team. ops intake makes the intakes a
repository declares with these functions.

Linear reads an intake by its id only; nothing lists them. So an intake is
found again by its id, which the lock records, and one made by hand is
adopted only when its id is given.

  linear__intake__team ASK "$options"
    ->  {"id":"e38b...","key":"ASK","templates":{"nodes":[{"id":"7f09...","name":"Docs feedback"}]}}
  linear__intake__input "$declared" e38b... 7f09...
    ->  {"forwardingEmailAddress":"docs@example.com","teamId":"e38b...","repliesEnabled":true,"templateId":"7f09..."}
  linear__intake__create "$input" "$options"
    ->  {"id":"3a1c...","address":"2371...@intake.linear.app"}
MODULE

# CONST: The kind of intake that carries a custom address with synced replies.
__linear__intake__TYPE='asks'

@obj __at1 '.existing' '.forwardingEmailAddress' '.input' '.forwardingEmailAddress'
@obj __at2 '.existing' '.team.id' '.input' '.teamId'
@obj __at3 '.existing' '.template.id' '.input' '.templateId'
@obj __at4 '.existing' '.repliesEnabled' '.input' '.repliesEnabled'
@arr __linear__intake__held_fields \
  "$__at1" \
  "$__at2" \
  "$__at3" \
  "$__at4"

: <<'CONST'
The fields an intake is held to, each as the path of the field on the intake
as Linear holds it and its path on the input linear__intake__input prints.
CONST
__linear__intake__HELD_FIELDS="$__linear__intake__held_fields"

: <<'PUB_FUN'
Prints the Linear options the intake functions take, with the token from
LINEAR_API_KEY.

usage: linear__intake__options
PUB_FUN
linear__intake__options() {
  @obj __linear__intake__options__out '.token' "${LINEAR_API_KEY:-}"
  println "$__linear__intake__options__out"
}

: <<'PUB_FUN'
Succeeds quietly when LINEAR_API_KEY is set; otherwise says so and returns 1.

usage: linear__intake__ready || exit 1
PUB_FUN
linear__intake__ready() {
  if @defined "${LINEAR_API_KEY:-}"; then
    return 0
  fi
  error "intake: LINEAR_API_KEY is not set."
  return 1
}

: <<'PUB_FUN'
Prints the input Linear takes for the declared intake <declared>, with its
team and, when it names one, its template resolved to their ids. Fails
naming what Linear does not have.

  linear__intake__resolve "$declared" "$options"
    ->  {"forwardingEmailAddress":"docs@example.com","teamId":"e38b...","repliesEnabled":true,"templateId":"7f09..."}

args:
  $1  The declared intake ({address, team, template, replies})
  $2  The Linear options ({token})
PUB_FUN
linear__intake__resolve() {
  @get __linear__intake__resolve__get_5 "$1" '.team'
  __linear__intake__resolve__team="$(linear__intake__team "$__linear__intake__resolve__get_5" "$2")" || return 1
  __linear__intake__resolve__template_id="$(__linear__intake__declared_template_id "$__linear__intake__resolve__team" "$1")" || return 1
  @get __linear__intake__resolve__get_6 "$__linear__intake__resolve__team" '.id'
  linear__intake__input "$1" "$__linear__intake__resolve__get_6" "$__linear__intake__resolve__template_id"
}

: <<'FUN'
Prints the id of the template the declared intake names on the team, or
nothing when it names none; fails when the team has no template of that
name.

args:
  $1  The team, as linear__intake__team prints it
  $2  The declared intake
FUN
__linear__intake__declared_template_id() {
  @get __linear__intake__declared_template_id__name "$2" '.template' ''
  if ! @defined "$__linear__intake__declared_template_id__name"; then
    return 0
  fi
  linear__intake__template_id "$1" "$__linear__intake__declared_template_id__name"
}

: <<'PUB_FUN'
Prints the team whose key is <key>, with its id and its templates, or fails
naming the key when Linear has no such team.

  linear__intake__team ASK "$options"
    ->  {"id":"e38b...","key":"ASK","templates":{"nodes":[{"id":"7f09...","name":"Docs feedback"}]}}

args:
  $1  The team's key, for example ASK
  $2  The Linear options ({token})
PUB_FUN
linear__intake__team() {
  @obj __linear__intake__team__obj_7 '.key' "$1"
  __linear__intake__team__result="$(__linear__intake__request get-team-templates "$__linear__intake__team__obj_7" "$2")" || return 1
  @get __linear__intake__team__team "$__linear__intake__team__result" '.teams.nodes[0]' ''
  if ! @defined "$__linear__intake__team__team"; then
    error "intake: Linear has no team with the key $1."
    return 1
  fi
  println "$__linear__intake__team__team"
}

: <<'PUB_FUN'
Prints the id of the template named <name> among the templates of <team>, or
fails naming both when the team has no template of that name.

  linear__intake__template_id "$team" "Docs feedback"   ->  7f09...

args:
  $1  The team, as linear__intake__team prints it
  $2  The template's name
PUB_FUN
linear__intake__template_id() {
  @arr __linear__intake__template_id__arr_8
  @get __linear__intake__template_id__templates "$1" '.templates.nodes' "$__linear__intake__template_id__arr_8"
  @find __linear__intake__template_id__match __linear__intake__template_named "$__linear__intake__template_id__templates" "$2"
  if [ "$__linear__intake__template_id__match" = "null" ] || ! @defined "$__linear__intake__template_id__match"; then
    @get __linear__intake__template_id__get_9 "$1" '.key'
    error "intake: the team $__linear__intake__template_id__get_9 has no template named $2."
    return 1
  fi
  @get __linear__intake__template_id__out "$__linear__intake__template_id__match" '.id'
  println "$__linear__intake__template_id__out"
}

: <<'FUN'
@find callback: matches when the template's name is <name>.

args:
  $1  A template ({id, name})
  $2  The name wanted
FUN
__linear__intake__template_named() {
  @get __linear__intake__template_named__get_10 "$1" '.name'
  [ "$__linear__intake__template_named__get_10" = "$2" ]
}

: <<'PUB_FUN'
Prints the input Linear takes for the intake <declared>: its custom address,
the team <team_id>, the template <template_id> when there is one, and whether
replies sync between the mail thread and the issue, true unless the
declaration says otherwise.

  linear__intake__input "$declared" e38b... ""
    ->  {"forwardingEmailAddress":"docs@example.com","teamId":"e38b...","repliesEnabled":true}

args:
  $1  The declared intake ({address, team, template, replies})
  $2  The team's id
  $3  The template's id, or empty for none
PUB_FUN
linear__intake__input() {
  @get __linear__intake__input__get_11 "$1" '.address'
  @get __linear__intake__input__get_12 "$1" '.replies' true
  @obj __linear__intake__input__input \
    '.forwardingEmailAddress' "$__linear__intake__input__get_11" \
    '.teamId' "$2" \
    '.repliesEnabled' "$__linear__intake__input__get_12"
  if @defined "$3"; then
    @set __linear__intake__input__input "$__linear__intake__input__input" '.templateId' "$3"
  fi
  println "$__linear__intake__input__input"
}

: <<'PUB_FUN'
Prints the intake with the id <id> as Linear holds it: id, address, type,
enabled, forwardingEmailAddress, repliesEnabled, team and template. Fails
naming the id when Linear has no such intake.

args:
  $1  The intake's id
  $2  The Linear options ({token})
PUB_FUN
linear__intake__get() {
  @obj __linear__intake__get__obj_13 '.id' "$1"
  __linear__intake__get__result="$(__linear__intake__request email-intake-get "$__linear__intake__get__obj_13" "$2")" || return 1
  @get __linear__intake__get__intake "$__linear__intake__get__result" '.emailIntakeAddress' ''
  if ! @defined "$__linear__intake__get__intake"; then
    error "intake: Linear has no intake with the id $1."
    return 1
  fi
  println "$__linear__intake__get__intake"
}

: <<'PUB_FUN'
Creates an intake of the kind that carries a custom address from <input>, and
prints its id and the address Linear generated for it.

  linear__intake__create "$input" "$options"   ->  {"id":"3a1c...","address":"2371...@intake.linear.app"}

args:
  $1  The input, as linear__intake__input prints it
  $2  The Linear options ({token})
PUB_FUN
linear__intake__create() {
  @set __linear__intake__create__input "$1" '.type' "$__linear__intake__TYPE"
  @obj __linear__intake__create__variables '.input' "$__linear__intake__create__input"
  __linear__intake__create__result="$(__linear__intake__request email-intake-create "$__linear__intake__create__variables" "$2")" || return 1
  __linear__check_success "$__linear__intake__create__result" emailIntakeAddressCreate || return 1
  @get __linear__intake__create__out "$__linear__intake__create__result" '.emailIntakeAddressCreate.emailIntakeAddress'
  println "$__linear__intake__create__out"
}

: <<'PUB_FUN'
Updates the intake with the id <id> to <input>, and prints its id and the
address Linear generated for it, which an update keeps.

args:
  $1  The intake's id
  $2  The input, as linear__intake__input prints it
  $3  The Linear options ({token})
PUB_FUN
linear__intake__update() {
  @obj __linear__intake__update__variables '.id' "$1" '.input' "$2"
  __linear__intake__update__result="$(__linear__intake__request email-intake-update "$__linear__intake__update__variables" "$3")" || return 1
  __linear__check_success "$__linear__intake__update__result" emailIntakeAddressUpdate || return 1
  @get __linear__intake__update__out "$__linear__intake__update__result" '.emailIntakeAddressUpdate.emailIntakeAddress'
  println "$__linear__intake__update__out"
}

: <<'PUB_FUN'
Prints what the lock keeps for an intake as Linear answers it: its id, by
which it is found again, and the address Linear generated for it.

  linear__intake__lock_entry "$created"   ->  {"id":"3a1c...","address":"2371...@intake.linear.app"}

args:
  $1  The intake, as Linear answers it ({id, address, ...})
PUB_FUN
linear__intake__lock_entry() {
  @get __linear__intake__lock_entry__get_14 "$1" '.id'
  @get __linear__intake__lock_entry__get_15 "$1" '.address'
  @obj __linear__intake__lock_entry__out \
    '.id' "$__linear__intake__lock_entry__get_14" \
    '.address' "$__linear__intake__lock_entry__get_15"
  println "$__linear__intake__lock_entry__out"
}

: <<'PUB_FUN'
Prints true when the intake <existing>, as linear__intake__get prints it, is
disabled or differs from <input> in any field an intake is held to: its
custom address, its team, its template or its reply sync; false when it
matches.

  linear__intake__drift "$existing" "$input"   ->  false

args:
  $1  The intake as Linear holds it
  $2  The input, as linear__intake__input prints it
PUB_FUN
linear__intake__drift() {
  if @get __linear__intake__drift__get_16 "$1" '.enabled' true; [ "$__linear__intake__drift__get_16" != "true" ]; then
    @true __linear__intake__drift__out
    println "$__linear__intake__drift__out"
    return 0
  fi
  @any __linear__intake__drift__out __linear__intake__field_differs "$__linear__intake__HELD_FIELDS" "$1" "$2"
  println "$__linear__intake__drift__out"
}

: <<'FUN'
@any callback: matches when the field that <pair> names differs between the
intake <existing>, as Linear holds it, and the input <input>.

args:
  $1  The pair ({existing, input}): the field's path on each side
  $2  The intake as Linear holds it
  $3  The input
FUN
__linear__intake__field_differs() {
  @get __linear__intake__field_differs__existing_path "$1" '.existing'
  @get __linear__intake__field_differs__input_path "$1" '.input'
  @get __linear__intake__field_differs__held "$2" "$__linear__intake__field_differs__existing_path" ''
  @get __linear__intake__field_differs__wanted "$3" "$__linear__intake__field_differs__input_path" ''
  [ "$__linear__intake__field_differs__held" != "$__linear__intake__field_differs__wanted" ]
}

: <<'FUN'
Runs the Linear document <operation> with <variables> and prints the data it
answers.

args:
  $1  The document's name, a .graphql file beside lib/linear/api.sh
  $2  The variables, as a struct
  $3  The Linear options ({token})
FUN
__linear__intake__request() {
  __linear__intake__request__token="$(__linear__validate_token "$3")" || return 1
  __linear__intake__request__http_opts="$(__linear__http_opts "$__linear__intake__request__token")"
  __linear__intake__request__query="$(graphql__load "$__linear__GRAPHQL_DIR" "$1")" || return 1
  graphql__request \
    "$__linear__ENDPOINT" \
    "$__linear__intake__request__http_opts" \
    "$__linear__intake__request__query" \
    "$2"
}
