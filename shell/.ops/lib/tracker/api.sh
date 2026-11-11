#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/kinds/api.sh" \
  "$SHELLOPS_DIR/lib/self/config.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Trackers: a project's plan as a DAG, read and written through whichever
trackers the project declares, as one plan however many hold it.

A plan is tickets with blocking edges, laid out by milestone, cut from a
tracker's whole graph by a scope. A repository declares its scopes as the
`trackers` list of its manifest declaration, since an organisation may keep
an internal tracker and a public one at once; a single `tracker` block is a
list of one, and a repository with neither gets a scope for its linear-team
and one for a plan file at .ops/data/plan.yaml (tracker__scopes).

A tracker is a plugin of kind tracker (lib/kinds/api.sh says how a kind
loads), a file named <name>.tracker.op.sh defining @tracker.<name>() with
the roles below, each taking the scope first. A role fails, naming it, on a
ticket it cannot find or a state the tracker does not have. The trackers: file, a
plan kept in a YAML file under the repository, here, and linear, a team and
one of its projects through Linear's API, kept with the Linear library under
lib/linear. Importing this module loads every tracker under lib/.

tracker__declared_plan is the plan of the whole repository, the union over
every declared scope. A tracker records only its own edges, so a
cross-tracker edge is a line "Blocked by <key>" or "Blocks <key>" in a
ticket's description, the key prefixed with its tracker's name and a colon
when the key alone could be read two ways. The union reads those lines,
drops a stub another declared tracker holds, and keeps one no tracker holds.

Roles:
  @plan <scope>                        Prints the scope's plan.
  @states <scope>                      Prints the tracker's states, in the
                                       tracker's order.
  @tickets <scope> <filter>            Prints the tickets <filter> keeps,
                                       of every ticket of the scope.
  @ticket <scope> <key>                Prints the ticket <key>.
  @update <scope> <key> <changes>      Sets the ticket's state to the state
                                       named .state and its milestone to
                                       .milestone of <changes>, each when
                                       not empty; prints the ticket as it
                                       is then.
  @link <scope> <blocker> <blocked>    Records that one ticket blocks the
                                       other; prints the edge.
  @unlink <scope> <blocker> <blocked>  Drops that edge; prints nothing.
  @create <scope> <ticket>             Creates a ticket from the .title,
                                       .state, .milestone, .estimate and
                                       .description of <ticket>; prints it
                                       with the key the tracker gave it.
  @delete <scope> <key>                Deletes the ticket <key> and the
                                       edges that reach it; prints nothing.

Returns:
  A scope is {name, kind, org, key, project}: a name of the repository's
  choosing (the kind when it gives none), the kind of tracker, the org the
  tracker's account belongs to (a GitHub owner; empty where the credential
  implies it), the key of what owns the tickets within it (a Linear team's
  key, a GitHub repository's name, a plan file's path) and, when named, the
  project inside it.
  A plan is {scope, states, milestones, tickets, edges}, its shape
  lib/tracker/plan.schema.json. A state is {name, type}: the tracker's own
  name for it, and one of tracker__types, the six kinds of state work moves
  through, so a reader groups the states of any tracker the same way. The
  milestones are [{id, name, target}] in the tracker's order. A ticket is
  {id, key, title, state, estimate, priority, assignee, milestone, lane,
  url, description, stub, tracker}: key is the name the tracker gives it
  (SHOP-44) and the name edges use, id the tracker's own for writes, state
  one of the tracker's states, milestone the id of the milestone it sits
  under, lane the column it stacks in (its initiative, else its project, as
  the tracker names it, or null), stub true for a ticket outside the scope
  that an edge reaches, and tracker the name of the scope it came from. An edge is {blocker, blocked}, both keys.
MODULE

# CONST: The roles a tracker may declare.
__tracker__ROLES="plan states tickets ticket update link unlink create delete"

# CONST: The roles a tracker must declare.
__tracker__REQUIRED="plan states tickets ticket update link unlink create delete"

# CONST: The types a state of any tracker is of, as a struct string array.
@arr __tracker__TYPES backlog todo in_progress in_review "done" cancelled

# CONST: The plan file a repository with no tracker keeps, relative to its root: under .ops/data, the XDG data of the project, what a program writes and reads back and the repository keeps.
__tracker__PLAN_FILE=".ops/data/plan.yaml"

# CONST: The directory of this module's awk programs.
__tracker__DIR="$SHELLOPS_DIR/lib/tracker"

: <<'PUB_FUN'
Loads and registers the tracker <name>, whose plugin file has been imported.
See kinds__load.
PUB_FUN
tracker__load() {
  kinds__load tracker "$1" "$__tracker__ROLES" "$__tracker__REQUIRED"
}

: <<'PUB_FUN'
Finds and loads every tracker under <root>. See kinds__scan.
PUB_FUN
tracker__load_trackers() {
  kinds__scan tracker "$1" "$__tracker__ROLES" "$__tracker__REQUIRED"
}

: <<'PUB_FUN'
Prints the names of every tracker, as a struct array, in load order.
PUB_FUN
tracker__names() {
  kinds__names tracker
}

: <<'PUB_FUN'
Prints the types a tracker's states are of, as a struct string array, in
the order work moves through them: backlog, todo, in_progress, in_review,
done, cancelled. A tracker gives each of its own states one of them.
PUB_FUN
tracker__types() {
  println "$__tracker__TYPES"
}

: <<'PUB_FUN'
Prints true when <type> is one of the types, false otherwise.

Usage: tracker__is_type in_review
PUB_FUN
tracker__is_type() {
  @any __tracker__is_type__out __tracker__type_equals "$(tracker__types)" "$1"
  println "$__tracker__is_type__out"
}

: <<'FUN'
Succeeds when the struct string <element> is the type <type>; the callback
@any runs over the types.
FUN
__tracker__type_equals() {
  @unwrap __tracker__type_equals__unwrap_1 "$1"
  [ "$__tracker__type_equals__unwrap_1" = "$2" ]
}

: <<'PUB_FUN'
Prints a state: the tracker's own <name> for it and its <type>, one of
tracker__types.

Usage: tracker__new_state "In Review" in_review
PUB_FUN
tracker__new_state() {
  @wrap __tracker__new_state__wrap_2 "$1"
  @wrap __tracker__new_state__wrap_3 "$2"
  @obj __tracker__new_state__out '.name' "$__tracker__new_state__wrap_2" '.type' "$__tracker__new_state__wrap_3"
  println "$__tracker__new_state__out"
}

: <<'PUB_FUN'
Prints the types as states, each named for its type: the states a tracker
has when it declares none of its own.

  tracker__default_states  ->  [{"name":"backlog","type":"backlog"}, ..., {"name":"cancelled","type":"cancelled"}]
PUB_FUN
tracker__default_states() {
  @map __tracker__default_states__out __tracker__default_state "$(tracker__types)"
  println "$__tracker__default_states__out"
}

: <<'FUN'
Prints the state named for the struct string <type>, of that type; the
callback @map runs over the types.
FUN
__tracker__default_state() {
  @unwrap __tracker__default_state__unwrap_4 "$1"
  @unwrap __tracker__default_state__unwrap_5 "$1"
  tracker__new_state "$__tracker__default_state__unwrap_4" "$__tracker__default_state__unwrap_5"
}

: <<'PUB_FUN'
Prints the state named <name> among the states <states>, failing, naming
the states there are, when none has that name.

Usage: tracker__state_named "$(tracker__states "$scope")" "In Review"
PUB_FUN
tracker__state_named() {
  @filter __tracker__state_named__found "$1" silt__text_is .name "$2"
  if @empty "$__tracker__state_named__found"; then
    @pluck __tracker__state_named__pluck_6 "$1" '.name'
    @join __tracker__state_named__join_7 "$__tracker__state_named__pluck_6" ', '
    error "no state named $2; the tracker's states: $__tracker__state_named__join_7"
    return 1
  fi

  @first __tracker__state_named__out "$__tracker__state_named__found"
  println "$__tracker__state_named__out"
}

: <<'PUB_FUN'
Prints a scope: the tracker <kind>, the <key> of what owns the tickets, the
<project> inside it when given, the scope's <name>, the kind when none is
given, and the <org> when the tracker needs one. A scope is what every role
takes first.

Usage: tracker__new_scope linear SHOP "Hermes Hackathon"
       tracker__new_scope github hermes-agent "" public creature-workshop
PUB_FUN
tracker__new_scope() {
  @wrap __tracker__new_scope__wrap_8 "${4:-$1}"
  @wrap __tracker__new_scope__wrap_9 "$1"
  @wrap __tracker__new_scope__wrap_10 "${5:-}"
  @wrap __tracker__new_scope__wrap_11 "$2"
  @wrap __tracker__new_scope__wrap_12 "${3:-}"
  @obj __tracker__new_scope__out \
    '.name' "$__tracker__new_scope__wrap_8" \
    '.kind' "$__tracker__new_scope__wrap_9" \
    '.org' "$__tracker__new_scope__wrap_10" \
    '.key' "$__tracker__new_scope__wrap_11" \
    '.project' "$__tracker__new_scope__wrap_12"
  println "$__tracker__new_scope__out"
}

: <<'PUB_FUN'
Prints a filter that keeps every ticket. Set a field with @set to keep only
the tickets that match it, every set field at once: .state the name of one
of the tracker's states, .type one of tracker__types, .milestone the id of
a milestone, .assignee an assignee's name. A tracker sends what it can of
the filter to its API and applies the rest itself.

Usage: filter="$(@set "$(tracker__new_filter)" '.type' in_progress)"
PUB_FUN
tracker__new_filter() {
  @obj __tracker__new_filter__out \
    '.state' "" \
    '.type' "" \
    '.milestone' "" \
    '.assignee' ""
  println "$__tracker__new_filter__out"
}

: <<'PUB_FUN'
Prints the tickets of <tickets> that the filter <filter> keeps: every one
whose fields equal each set field of the filter, so a tracker applies the
part of a filter its API cannot.

Usage: tracker__filter_tickets "$tickets" "$filter"
PUB_FUN
tracker__filter_tickets() {
  @run_awk __tracker__filter_tickets__out "$__tracker__DIR/filter_tickets.awk" "$1" --with "$2" || return 1
  println "$__tracker__filter_tickets__out"
}

: <<'PUB_FUN'
Prints the changes an update takes, with nothing changed yet: set .state to
the name of one of the tracker's states, or .milestone, or both, with @set
before the update.

Usage: changes="$(@set "$(tracker__new_changes)" '.state' "In Review")"
PUB_FUN
tracker__new_changes() {
  @obj __tracker__new_changes__out \
    '.state' "" \
    '.milestone' ""
  println "$__tracker__new_changes__out"
}

: <<'PUB_FUN'
Prints a ticket to create, with its defaults: no title, no state, no
milestone, no estimate and no description. Set the fields with @set before
the create. The state is the name of one of the tracker's states, and a
ticket created with no state gets the tracker's own default: the file
tracker's is its first state of type todo, and Linear's is the team's
default state.

Usage: ticket="$(@set "$(tracker__new_ticket)" '.title' "Record the demo" '.estimate' 2)"
PUB_FUN
tracker__new_ticket() {
  @obj __tracker__new_ticket__out \
    '.title' "" \
    '.state' "" \
    '.milestone' "" \
    '.estimate' "" \
    '.description' ""
  println "$__tracker__new_ticket__out"
}

: <<'PUB_FUN'
Prints the scopes the repository <root> declares, as a struct array in
declaration order: the `trackers` list of its manifest declaration, or its
single `tracker` block as a list of one, and when it has neither, a scope
for the linear team its manifest names and one for the plan file at
.ops/data/plan.yaml, whichever it has. Fails, saying what a repository declares
a tracker with, when there is none.

  tracker__scopes     ->  [{"name":"linear","kind":"linear","org":"","key":"SHOP","project":"Hermes Hackathon"}]
  tracker__scopes /p  ->  [{"name":"file","kind":"file","org":"","key":".ops/data/plan.yaml","project":""}]

args:
  $1  The repository's root; $PROJ when omitted
PUB_FUN
tracker__scopes() {
  __tracker__scopes__root="${1:-$PROJ}"
  __tracker__scopes__declared="$(__tracker__scopes__declared "$__tracker__scopes__root")" || return 1
  if ! @empty "$__tracker__scopes__declared"; then
    @map __tracker__scopes__out __tracker__scopes__declared_scope "$__tracker__scopes__declared"
    println "$__tracker__scopes__out"
    return 0
  fi

  __tracker__scopes__fallback="$(__tracker__scopes__fallback "$__tracker__scopes__root")" || return 1
  if @empty "$__tracker__scopes__fallback"; then
    error "$__tracker__scopes__root declares no tracker: add a trackers list to .ops/config/manifest.yaml, or keep a plan at $__tracker__PLAN_FILE"
    return 1
  fi

  println "$__tracker__scopes__fallback"
}

: <<'FUN'
Prints the scopes the manifest declaration of <root> lists under
`trackers`, or its single `tracker` block as a list of one, as the blocks
are written; empty when it has neither.
FUN
__tracker__scopes__declared() {
  @arr __tracker__scopes__declared__arr_13
  __tracker__scopes__declared__list="$(self__config__get manifest '.trackers' "$__tracker__scopes__declared__arr_13" "$1")" || return 1
  __tracker__scopes__declared__one="$(self__config__get manifest '.tracker' '' "$1")" || return 1
  if ! @empty "$__tracker__scopes__declared__list"; then
    println "$__tracker__scopes__declared__list"
  elif @get __tracker__scopes__declared__get_14 "$__tracker__scopes__declared__one" '.kind' ''; @defined "$__tracker__scopes__declared__get_14"; then
    @arr __tracker__scopes__declared__out "$__tracker__scopes__declared__one"
    println "$__tracker__scopes__declared__out"
  else
    @arr __tracker__scopes__declared__out
    println "$__tracker__scopes__declared__out"
  fi
}

: <<'FUN'
Prints the scopes a repository <root> gets without a trackers list: one for
the linear team its manifest names, one for its plan file, each when it
has it; empty when it has neither.
FUN
__tracker__scopes__fallback() {
  @arr __tracker__scopes__fallback__scopes
  __tracker__scopes__fallback__team="$(self__config__get manifest '."linear-team"' '' "$1")" || return 1
  if @defined "$__tracker__scopes__fallback__team"; then
    @push __tracker__scopes__fallback__scopes "$__tracker__scopes__fallback__scopes" "$(tracker__new_scope linear "$__tracker__scopes__fallback__team")"
  fi

  if [ -f "$1/$__tracker__PLAN_FILE" ]; then
    @push __tracker__scopes__fallback__scopes "$__tracker__scopes__fallback__scopes" "$(tracker__new_scope file "$__tracker__PLAN_FILE")"
  fi

  println "$__tracker__scopes__fallback__scopes"
}

: <<'FUN'
Prints the scope a declared block <declared> names, with its name, org,
key and project present even when the block leaves them out.
FUN
__tracker__scopes__declared_scope() {
  @get __tracker__scopes__declared_scope__get_15 "$1" '.kind'
  @get __tracker__scopes__declared_scope__get_16 "$1" '.key' ''
  @get __tracker__scopes__declared_scope__get_17 "$1" '.project' ''
  @get __tracker__scopes__declared_scope__get_18 "$1" '.kind'
  @get __tracker__scopes__declared_scope__get_19 "$1" '.name' "$__tracker__scopes__declared_scope__get_18"
  @get __tracker__scopes__declared_scope__get_20 "$1" '.org' ''
  tracker__new_scope \
    "$__tracker__scopes__declared_scope__get_15" \
    "$__tracker__scopes__declared_scope__get_16" \
    "$__tracker__scopes__declared_scope__get_17" \
    "$__tracker__scopes__declared_scope__get_19" \
    "$__tracker__scopes__declared_scope__get_20"
}

: <<'PUB_FUN'
Prints the first scope the repository <root> declares, for a caller that
works one tracker at a time. Fails as tracker__scopes fails.

args:
  $1  The repository's root; $PROJ when omitted
PUB_FUN
tracker__scope() {
  __tracker__scope__scopes="$(tracker__scopes "${1:-}")" || return 1
  @first __tracker__scope__out "$__tracker__scope__scopes"
  println "$__tracker__scope__out"
}

: <<'PUB_FUN'
Prints the scope named <name> among the scopes <scopes>, failing, naming
the scopes there are, when none has that name.

Usage: tracker__scope_named "$(tracker__scopes)" public
PUB_FUN
tracker__scope_named() {
  @filter __tracker__scope_named__found "$1" silt__text_is .name "$2"
  if @empty "$__tracker__scope_named__found"; then
    @pluck __tracker__scope_named__pluck_21 "$1" '.name'
    @join __tracker__scope_named__join_22 "$__tracker__scope_named__pluck_21" ', '
    error "no tracker named $2; the declared ones: $__tracker__scope_named__join_22"
    return 1
  fi

  @first __tracker__scope_named__out "$__tracker__scope_named__found"
  println "$__tracker__scope_named__out"
}

: <<'PUB_FUN'
Prints the plan of the whole repository <root>: the plans of every declared
scope as one, each ticket carrying its tracker's name, the edges each
tracker records joined by the ones written in prose, and a stub kept only
for a key no declared tracker holds.

args:
  $1  The repository's root; $PROJ when omitted
PUB_FUN
tracker__declared_plan() {
  __tracker__declared_plan__scopes="$(tracker__scopes "${1:-}")" || return 1
  @map __tracker__declared_plan__plans tracker__plan "$__tracker__declared_plan__scopes" || return 1
  @obj __tracker__declared_plan__obj_23 '.scopes' "$__tracker__declared_plan__scopes" '.plans' "$__tracker__declared_plan__plans"
  @run_awk __tracker__declared_plan__out "$__tracker__DIR/merge.awk" "$__tracker__declared_plan__obj_23" || return 1
  println "$__tracker__declared_plan__out"
}

: <<'PUB_FUN'
Prints the declared scope whose tracker holds the ticket <key>, failing,
naming the key, when none does.

Usage: tracker__scope_of_ticket SHOP-44
       tracker__scope_of_ticket org/repo#12 /p
PUB_FUN
tracker__scope_of_ticket() {
  __tracker__scope_of_ticket__plan="$(tracker__declared_plan "${2:-}")" || return 1
  @get __tracker__scope_of_ticket__get_24 "$__tracker__scope_of_ticket__plan" '.tickets'
  @filter __tracker__scope_of_ticket__keyed "$__tracker__scope_of_ticket__get_24" silt__text_is .key "$1"
  @filter __tracker__scope_of_ticket__found "$__tracker__scope_of_ticket__keyed" silt__text_is_not .stub true
  if @empty "$__tracker__scope_of_ticket__found"; then
    error "no ticket $1 in the plan of any declared tracker"
    return 1
  fi

  @first __tracker__scope_of_ticket__first_25 "$__tracker__scope_of_ticket__found"
  @get __tracker__scope_of_ticket__get_26 "$__tracker__scope_of_ticket__first_25" '.tracker'
  tracker__scope_named "$(tracker__scopes "${2:-}")" "$__tracker__scope_of_ticket__get_26"
}

: <<'FUN'
Prints the name of the tracker the scope <scope> names: its .kind.
FUN
__tracker__kind_of() {
  @get __tracker__kind_of__out "$1" '.kind'
  println "$__tracker__kind_of__out"
}

: <<'PUB_FUN'
Runs the scope's tracker's @plan: prints the plan of <scope>.

Usage: tracker__plan "$scope"
PUB_FUN
tracker__plan() {
  kinds__call tracker "$(__tracker__kind_of "$1")" plan "$1"
}

: <<'PUB_FUN'
Runs the scope's tracker's @tickets: prints the tickets of <scope> that the
filter <filter> keeps, every ticket when the filter is omitted, each
carrying the scope's name as its tracker.

Usage: tracker__tickets "$scope"
       tracker__tickets "$scope" "$(@set "$(tracker__new_filter)" '.type' in_progress)"
PUB_FUN
tracker__tickets() {
  __tracker__tickets__filter="${2:-$(tracker__new_filter)}"
  __tracker__tickets__tickets="$(kinds__call tracker "$(__tracker__kind_of "$1")" tickets "$1" "$__tracker__tickets__filter")" || return 1
  @map __tracker__tickets__out __tracker__with_tracker_of "$__tracker__tickets__tickets" "$1"
  println "$__tracker__tickets__out"
}

: <<'FUN'
Prints the ticket <ticket> carrying the name of the scope <scope> as its
tracker; the callback @map runs over a tracker's tickets, the scope after.
FUN
__tracker__with_tracker_of() {
  __tracker__with_tracker "$2" "$1"
}

: <<'PUB_FUN'
Runs the scope's tracker's @states: prints the states of <scope>, [{name,
type}], in the tracker's order.

Usage: tracker__states "$scope"
PUB_FUN
tracker__states() {
  kinds__call tracker "$(__tracker__kind_of "$1")" states "$1"
}

: <<'PUB_FUN'
Prints the states of every declared scope of the repository <root> as one
list, each carrying its tracker's name, in declaration order.

args:
  $1  The repository's root; $PROJ when omitted
PUB_FUN
tracker__declared_states() {
  __tracker__declared_states__scopes="$(tracker__scopes "${1:-}")" || return 1
  @map __tracker__declared_states__read __tracker__declared_states__of_scope "$__tracker__declared_states__scopes" || return 1
  @run_awk __tracker__declared_states__out "$__tracker__DIR/declared_states.awk" "$__tracker__declared_states__read" || return 1
  println "$__tracker__declared_states__out"
}

: <<'FUN'
Prints the scope <scope> with its states, {scope, states}; the callback
@map runs over the declared scopes.
FUN
__tracker__declared_states__of_scope() {
  __tracker__declared_states__of_scope__states="$(tracker__states "$1")" || return 1
  @obj __tracker__declared_states__of_scope__out '.scope' "$1" '.states' "$__tracker__declared_states__of_scope__states"
  println "$__tracker__declared_states__of_scope__out"
}

: <<'PUB_FUN'
Runs the scope's tracker's @ticket: prints the ticket <key> of <scope>,
carrying the scope's name as its tracker.

Usage: tracker__ticket "$scope" SHOP-44
PUB_FUN
tracker__ticket() {
  __tracker__ticket__ticket="$(kinds__call tracker "$(__tracker__kind_of "$1")" ticket "$1" "$2")" || return 1
  __tracker__with_tracker "$1" "$__tracker__ticket__ticket"
}

: <<'PUB_FUN'
Runs the scope's tracker's @update: changes the ticket <key> by <changes> and
prints it, carrying the scope's name as its tracker.

Usage: tracker__update "$scope" SHOP-44 "$changes"
PUB_FUN
tracker__update() {
  __tracker__update__ticket="$(kinds__call tracker "$(__tracker__kind_of "$1")" update "$1" "$2" "$3")" || return 1
  __tracker__with_tracker "$1" "$__tracker__update__ticket"
}

: <<'PUB_FUN'
Runs the scope's tracker's @link: records that <blocker> blocks <blocked>
and prints the edge.

Usage: tracker__link "$scope" SHOP-44 SHOP-45
PUB_FUN
tracker__link() {
  kinds__call tracker "$(__tracker__kind_of "$1")" link "$1" "$2" "$3"
}

: <<'PUB_FUN'
Runs the scope's tracker's @unlink: drops the edge from <blocker> to
<blocked>.

Usage: tracker__unlink "$scope" SHOP-44 SHOP-45
PUB_FUN
tracker__unlink() {
  kinds__call tracker "$(__tracker__kind_of "$1")" unlink "$1" "$2" "$3"
}

: <<'PUB_FUN'
Runs the scope's tracker's @create: creates <ticket> in the scope and prints
it with its key, carrying the scope's name as its tracker.

Usage: tracker__create "$scope" "$ticket"
PUB_FUN
tracker__create() {
  __tracker__create__ticket="$(kinds__call tracker "$(__tracker__kind_of "$1")" create "$1" "$2")" || return 1
  __tracker__with_tracker "$1" "$__tracker__create__ticket"
}

: <<'PUB_FUN'
Runs the scope's tracker's @delete: deletes the ticket <key> of <scope> and
the edges that reach it.

Usage: tracker__delete "$scope" SHOP-44
PUB_FUN
tracker__delete() {
  kinds__call tracker "$(__tracker__kind_of "$1")" delete "$1" "$2"
}

: <<'FUN'
Prints the ticket <ticket> carrying the name of the scope <scope> as its
tracker, the way the union plan's tickets do.
FUN
__tracker__with_tracker() {
  @get __tracker__with_tracker__get_27 "$1" '.name'
  @wrap __tracker__with_tracker__wrap_28 "$__tracker__with_tracker__get_27"
  @set __tracker__with_tracker__out "$2" '.tracker' "$__tracker__with_tracker__wrap_28"
  println "$__tracker__with_tracker__out"
}

: <<'PUB_FUN'
Prints the ticket <key> from whichever declared tracker holds it, failing,
naming the key, when none does.

Usage: tracker__find_ticket SHOP-44
       tracker__find_ticket SHOP-44 /p
PUB_FUN
tracker__find_ticket() {
  __tracker__find_ticket__scope="$(tracker__scope_of_ticket "$1" "${2:-}")" || return 1
  tracker__ticket "$__tracker__find_ticket__scope" "$1"
}

: <<'PUB_FUN'
Changes the ticket <key> by <changes> in whichever declared tracker holds it,
and prints the ticket. Fails, naming the key, when no declared tracker
holds it.

Usage: tracker__update_ticket SHOP-44 "$changes"
       tracker__update_ticket SHOP-44 "$changes" /p
PUB_FUN
tracker__update_ticket() {
  __tracker__update_ticket__scope="$(tracker__scope_of_ticket "$1" "${3:-}")" || return 1
  tracker__update "$__tracker__update_ticket__scope" "$1" "$2"
}

: <<'PUB_FUN'
Records that <blocker> blocks <blocked> in the tracker that holds them both,
and prints the edge. Two tickets of different trackers are linked by a
"Blocked by <key>" line in a description, which a tracker cannot write for
another, so that case fails and says what to write.

Usage: tracker__link_tickets SHOP-44 SHOP-45
PUB_FUN
tracker__link_tickets() {
  __tracker__link_tickets__blocker="$(tracker__scope_of_ticket "$1" "${3:-}")" || return 1
  __tracker__link_tickets__blocked="$(tracker__scope_of_ticket "$2" "${3:-}")" || return 1
  if @get __tracker__link_tickets__get_29 "$__tracker__link_tickets__blocker" '.name'; @get __tracker__link_tickets__get_30 "$__tracker__link_tickets__blocked" '.name'; [ "$__tracker__link_tickets__get_29" != "$__tracker__link_tickets__get_30" ]; then
    error "$1 and $2 are in different trackers; write \"Blocked by $1\" in $2's description instead"
    return 1
  fi

  tracker__link "$__tracker__link_tickets__blocked" "$1" "$2"
}

: <<'PUB_FUN'
Drops the edge from <blocker> to <blocked> in the tracker that holds
<blocked>.

Usage: tracker__unlink_tickets SHOP-44 SHOP-45
PUB_FUN
tracker__unlink_tickets() {
  __tracker__unlink_tickets__scope="$(tracker__scope_of_ticket "$2" "${3:-}")" || return 1
  tracker__unlink "$__tracker__unlink_tickets__scope" "$1" "$2"
}

: <<'PUB_FUN'
Deletes the ticket <key> from whichever declared tracker holds it, with the
edges that reach it. Fails, naming the key, when no declared tracker holds
it.

Usage: tracker__delete_ticket SHOP-44
PUB_FUN
tracker__delete_ticket() {
  __tracker__delete_ticket__scope="$(tracker__scope_of_ticket "$1" "${2:-}")" || return 1
  tracker__delete "$__tracker__delete_ticket__scope" "$1"
}

: <<'PUB_FUN'
Creates <ticket> in the declared tracker named <name>, or in the first
declared one when <name> is empty, and prints it with its key.

Usage: tracker__create_in public "$ticket"
       tracker__create_in "" "$ticket"
PUB_FUN
tracker__create_in() {
  __tracker__create_in__scopes="$(tracker__scopes "${3:-}")" || return 1
  if @defined "$1"; then
    __tracker__create_in__scope="$(tracker__scope_named "$__tracker__create_in__scopes" "$1")" || return 1
  else
    @first __tracker__create_in__scope "$__tracker__create_in__scopes"
  fi

  tracker__create "$__tracker__create_in__scope" "$2"
}

tracker__load_trackers "$SHELLOPS_DIR/lib"
