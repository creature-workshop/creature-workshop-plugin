# shellcheck shell=bash

# TODO(OPS-281): POSIXify this loader -- drop local/[[ ]]/<<</process-subst from
# the parts not touched by OPS-270.

__shellops_interpreter__snap() {
  declare -F | awk '{print $3}'
}

:<<'FUN'
Prints the function names present in <after> and absent from <before> -- the
functions a source added.

args:
  $1  The function-name snapshot taken before the source
  $2  The function-name snapshot taken after it
FUN
__shellops_interpreter__discover_new() {
  local before="$1"
  local after="$2"

  [[ -z "$after" ]] && return 0
  [[ -z "$before" ]] && { println "$after"; return 0; }

  # One grep over the whole before-list: the loader asks this of every file it
  # sources, and a scan per name costs a fork per name.
  grep -vxF -f <(println "$before") <(println "$after") || true
}

:<<'FUN'
Re-homes a discovered function under a new name and drops the original. The
function is global, so the eval'd copy outlives this call; the @-prefixed name is
unset to keep it out of scope.

args:
  $1  The discovered function name (e.g. @do)
  $2  The name to re-home it under
FUN
__shellops_interpreter__rehome_fn() {
  eval "$(declare -f "$1" | sed "1s/.*/${2} ()/")"
  unset -f "$1"
}

:<<'FUN'
Re-homes a discovered contract function under a collision-free mangled name and
points its dispatch key at it (the dispatcher invokes ops and types through this
table).

args:
  $1  The discovered function name
  $2  The mangled target name
  $3  The dispatch key (e.g. git.current-branch.do)
FUN
__shellops_interpreter__bind_contract_fn() {
  __shellops_interpreter__rehome_fn "$1" "$2"
  __dispatch["$3"]="$2"
}

:<<'FUN'
Generic structural-contract loader, shared by ops, types, and runners. Snapshots
the function namespace, calls <outer> (which defines its inner @-roles), and for
each newly-defined function whose role is in <roles> invokes <binder> <inner-fn>
<role>. Records the bound role list in __reg_contracts[<key>]. The kind-specific
wrapper stages its naming context in globals before calling this, and the
<binder> reads them back. __cur_op/__phase are set around the outer call.

args:
  $1  The __cur_op value to set around the outer call
  $2  The __reg_contracts key under which to record the bound roles
  $3  The outer function to invoke (defines the inner @-roles)
  $4  The space-separated set of role names to bind
  $5  The binder applied to each (inner-fn, role)
FUN
__shellops_interpreter__load_contract() {
  __shellops_interpreter__load_contract__cur="$1"
  __shellops_interpreter__load_contract__key="$2"
  __shellops_interpreter__load_contract__outer="$3"
  __shellops_interpreter__load_contract__roles="$4"
  __shellops_interpreter__load_contract__binder="$5"
  __shellops_interpreter__load_contract__contracts=""

  __cur_op="$__shellops_interpreter__load_contract__cur"
  __phase="register"
  __shellops_interpreter__load_contract__before=$(__shellops_interpreter__snap)
  "$__shellops_interpreter__load_contract__outer"
  __shellops_interpreter__load_contract__after=$(__shellops_interpreter__snap)
  __shellops_interpreter__load_contract__new=$(__shellops_interpreter__discover_new "$__shellops_interpreter__load_contract__before" "$__shellops_interpreter__load_contract__after")

  while IFS= read -r __shellops_interpreter__load_contract__fn; do
    [[ -z "$__shellops_interpreter__load_contract__fn" ]] && continue
    __shellops_interpreter__load_contract__cname="${__shellops_interpreter__load_contract__fn#@}"
    case " $__shellops_interpreter__load_contract__roles " in
      *" $__shellops_interpreter__load_contract__cname "*) ;;
      *) continue ;;
    esac
    "$__shellops_interpreter__load_contract__binder" \
      "$__shellops_interpreter__load_contract__fn" \
      "$__shellops_interpreter__load_contract__cname"
    __shellops_interpreter__load_contract__contracts="${__shellops_interpreter__load_contract__contracts}${__shellops_interpreter__load_contract__cname} "
  done <<< "$__shellops_interpreter__load_contract__new"

  __reg_contracts["$__shellops_interpreter__load_contract__key"]="$__shellops_interpreter__load_contract__contracts"
  __cur_op=""
  __phase=""
}

:<<'PUB_FUN'
Registers an operation under its fully-qualified registry name. The dispatch
mangling consumes the full dotted FQN, so mangled inner names stay collision-free
across modules (git.current-branch -> __op__git__current_branch__do).

args:
  $1  The path-derived registry FQN (e.g. git.current-branch)
  $2  The module-relative outer function to invoke (e.g. @operation.current-branch);
      its inner declaration names only the local op, the namespace comes from the path
PUB_FUN
interpreter__load_op() {
  __shellops_interpreter__load_op__name="$1"
  __shellops_interpreter__load_op__prefix="${1//\./__}"

  __shellops_interpreter__load_contract \
    "$1" "$1" "$2" "do undo is-done" __shellops_interpreter__bind_op
}

:<<'FUN'
Binder for op roles: re-homes to __op__<prefix>__<role> and keys the dispatcher
on <name>.<role>. Reads the name/prefix staged by interpreter__load_op.

args:
  $1  The inner contract function (e.g. @do)
  $2  The role name (e.g. do)
FUN
__shellops_interpreter__bind_op() {
  __shellops_interpreter__bind_contract_fn "$1" \
    "__op__${__shellops_interpreter__load_op__prefix}__${2//-/_}" \
    "${__shellops_interpreter__load_op__name}.${2}"
}

:<<'PUB_FUN'
Registers a type. Module types are namespaced like ops: the FQN is
<module-path-dotted>.<local-name>, derived from the folder and passed in by
discovery; <fqn> defaults to the bare local name (top-level / inline use).

args:
  $1  The outer @type.<local-name> function to invoke
  $2  The fully-qualified type name (optional; defaults to the bare local name)
PUB_FUN
interpreter__load_type() {
  __shellops_interpreter__load_type__local_name="${1#@type.}"
  __shellops_interpreter__load_type__name="${2:-$__shellops_interpreter__load_type__local_name}"
  __shellops_interpreter__load_type__prefix="type__${__shellops_interpreter__load_type__name//[.-]/_}"
  __shellops_interpreter__load_type__is_fn=""
  __shellops_interpreter__load_type__default_fn=""

  __shellops_interpreter__load_contract \
    "type:$__shellops_interpreter__load_type__name" \
    "type:$__shellops_interpreter__load_type__name" \
    "$1" "is default" __shellops_interpreter__bind_type

  [[ -n "$__shellops_interpreter__load_type__is_fn" ]] && __shellops_interpreter__type_register \
    "$__shellops_interpreter__load_type__name" \
    "$__shellops_interpreter__load_type__is_fn" \
    "$__shellops_interpreter__load_type__default_fn"
}

:<<'FUN'
Binder for type roles: re-homes to __<prefix>__<role>, keys the dispatcher on
type:<name>.<role>, and records the is/default mangled names for type_register.
Reads name/prefix and writes is_fn/default_fn in interpreter__load_type's globals.

args:
  $1  The inner contract function (@is or @default)
  $2  The role name (is or default)
FUN
__shellops_interpreter__bind_type() {
  __shellops_interpreter__bind_type__mangled="__${__shellops_interpreter__load_type__prefix}__${2//-/_}"
  __shellops_interpreter__bind_contract_fn "$1" \
    "$__shellops_interpreter__bind_type__mangled" \
    "type:${__shellops_interpreter__load_type__name}.${2}"
  if [[ "$2" == "is" ]]; then
    __shellops_interpreter__load_type__is_fn="$__shellops_interpreter__bind_type__mangled"
  else
    __shellops_interpreter__load_type__default_fn="$__shellops_interpreter__bind_type__mangled"
  fi
}

:<<'PUB_FUN'
Loads a @runner.<id>() structural contract: re-homes its inner roles to the flat
<id>_<role> functions the testing adapter and resolver call directly. Runners are
invoked by name (command -v <id>_<role>), not through the op dispatcher, so the
roles are re-homed without a __dispatch entry. A missing required role is a loud
failure naming the runner and the gap.

Required roles: run_selected, run_all, suite_schema, suite_defaults.
Optional roles:
  strategies        the discovery strategies the runner opts into
  discover          resolves one runner-owned strategy for one area
  discover_all      resolves one runner-owned strategy for every area in a
                    single call; when a runner defines it, the resolver calls
                    it instead of calling discover once per area. For example:

                      cargo_discover_all crate '{"engine": ["engine"]}' '["*.rs"]' '[]'
                      -> {"engine": ["engine/cache/src/state.rs"]}

  coverage_summary  prints the suite's last run as a normalized coverage report
                    (the shape lib/coverage/api.sh gates on); only a runner that
                    instruments its run defines it
  escape_key        names, for a suite config, how the escape join reads a
                    JUnit classname the suite's run wrote: "file-path" (a
                    repo-relative test file, the default when the role is
                    absent) or "package" (a cargo package, with an optional
                    ::binary suffix)
  selected_packages the packages a selection of test files narrows the run
                    to; a runner whose escape_key is "package" defines it so
                    the record can carry what the join matches against
  junit_path        the absolute path of the JUnit report a run of the suite
                    config leaves behind, or nothing when that run writes
                    none; the record counts the run's flaky tests from it

args:
  $1  The runner id (e.g. bats)
  $2  The outer @runner.<id> function to invoke
PUB_FUN
interpreter__load_runner() {
  __shellops_interpreter__load_runner__id="$1"

  __shellops_interpreter__load_contract \
    "runner:$1" "runner:$1" "$2" \
    "run_selected run_all suite_schema suite_defaults strategies discover discover_all coverage_summary escape_key selected_packages junit_path" \
    __shellops_interpreter__bind_runner

  __shellops_interpreter__require_roles \
    "interpreter__load_runner: runner $1" \
    "$1" "run_selected run_all suite_schema suite_defaults"
}

:<<'FUN'
Binder for runner roles: re-homes @<role> to the flat <id>_<role> name (no
dispatch entry). Reads the id staged by interpreter__load_runner.

args:
  $1  The inner contract function (e.g. @run_selected)
  $2  The role name (e.g. run_selected)
FUN
__shellops_interpreter__bind_runner() {
  __shellops_interpreter__rehome_fn "$1" "${__shellops_interpreter__load_runner__id}_${2//-/_}"
}

:<<'PUB_FUN'
Loads one lint check: a @check.<name>() function whose inner @-functions are
its roles. Each inner @<role> becomes a plain function named <prefix>_<role>,
where <prefix> is the check name with dashes turned to underscores
(doc-comment -> doc_comment_run). Checks are called by name, not through the op
dispatcher, so no __dispatch entry is made. A missing role fails the load and
says which.

Roles, all required: run, languages, scopes, summary, hint. shell-lint's shell/lint/registry.sh
says what each means.

args:
  $1  The check name (e.g. doc-comment)
  $2  The outer @check.<name> function to invoke
PUB_FUN
interpreter__load_check() {
  __shellops_interpreter__load_check__prefix="${1//-/_}"

  __shellops_interpreter__load_contract \
    "check:$1" "check:$1" "$2" \
    "run languages scopes summary hint" \
    __shellops_interpreter__bind_check

  __shellops_interpreter__require_roles \
    "interpreter__load_check: check $1" \
    "$__shellops_interpreter__load_check__prefix" "run languages scopes summary hint"
}

:<<'FUN'
Binder for check roles: re-homes @<role> to the flat <prefix>_<role> name (no
dispatch entry). Reads the prefix staged by interpreter__load_check.

args:
  $1  The inner contract function (e.g. @run)
  $2  The role name (e.g. run)
FUN
__shellops_interpreter__bind_check() {
  __shellops_interpreter__rehome_fn "$1" "${__shellops_interpreter__load_check__prefix}_${2//-/_}"
}

:<<'PUB_FUN'
Loads a @forge.<id>() contract: each inner @<role> becomes <id>_<role>, called
by name and never through the op dispatcher. api_base and run_status are
required; every other role is optional. A missing required role fails naming
the forge and the role.

args:
  $1  The forge id (e.g. gitlab)
  $2  The outer @forge.<id> function to invoke
PUB_FUN
interpreter__load_forge() {
  __shellops_interpreter__load_forge__id="$1"

  @join __interpreter__load_forge__join_1 "$__shellops_interpreter__FORGE_ROLES" ' '
  __shellops_interpreter__load_contract \
    "forge:$1" "forge:$1" "$2" \
    "$__interpreter__load_forge__join_1" \
    __shellops_interpreter__bind_forge

  @join __interpreter__load_forge__join_2 "$__shellops_interpreter__FORGE_REQUIRED" ' '
  __shellops_interpreter__require_roles \
    "interpreter__load_forge: forge $1" \
    "$1" "$__interpreter__load_forge__join_2"
}

@arr __interpreter__forge_roles \
  api_base token_env run_status create_release upload_artifact \
  get_review create_review update_review \
  list_comments create_comment \
  list_review_comments create_review_comment update_review_comment delete_review_comment \
  list_review_thread_comments \
  list_labels create_label edit_label reconcile_review_labels review_labels \
  list_org_repos get_raw_file default_branch \
  merged_reviews_since code_review_refs current_review comment_is_reply pushed_range \
  request_review reviews_awaiting_author mention review_ref review_from_url review_url repository review_commit_range \
  review_for_branch review_pipeline download_job_artifacts no_run_push_options \
  create_commit_status \
  current_run branch_head running_runs cancel_run landing_at \
  open_reviews review_approval landing_run start_landing_run merge_review \
  current_user

: <<'CONST'
The roles a forge may declare, the facade's dispatch surface, and the two it
must.
CONST
__shellops_interpreter__FORGE_ROLES="$__interpreter__forge_roles"  # private-name-check: allow -- every name in this file carries the shellops_ prefix
@arr __shellops_interpreter__FORGE_REQUIRED api_base run_status

:<<'FUN'
Re-homes @<role> to <id>_<role> for the forge interpreter__load_forge staged.

args:
  $1  The inner contract function (e.g. @run_status)
  $2  The role name (e.g. run_status)
FUN
__shellops_interpreter__bind_forge() {
  __shellops_interpreter__rehome_fn "$1" "${__shellops_interpreter__load_forge__id}_${2//-/_}"
}

:<<'PUB_FUN'
Loads one plugin of any kind: a @<kind>.<name>() function whose inner
@-functions are its roles. Each inner @<role> becomes a plain function named
<prefix>_<role>, where <prefix> is the plugin name with dashes turned to
underscores (fork-tree -> fork_tree_run). Plugins are called by name, not
through the op dispatcher, so no __dispatch entry is made. A missing required
role fails the load and says which.

Every kind may declare @needs, the programs the plugin runs, whether or not
the kind's contract lists it; it is bound when present so a caller can ask
any plugin what it needs before running it.

args:
  $1  The kind (e.g. profile)
  $2  The plugin name (e.g. forks)
  $3  The outer @<kind>.<name> function to invoke
  $4  The space-separated roles the kind knows
  $5  The space-separated roles the kind requires
PUB_FUN
interpreter__load_kind() {
  __shellops_interpreter__load_kind__prefix="${2//-/_}"

  __shellops_interpreter__load_contract \
    "$1:$2" "$1:$2" "$3" \
    "$4 needs" \
    __shellops_interpreter__bind_kind

  __shellops_interpreter__require_roles \
    "interpreter__load_kind: $1 $2" \
    "$__shellops_interpreter__load_kind__prefix" "$5"
}

:<<'FUN'
Binder for any kind's roles: re-homes @<role> to the flat <prefix>_<role>
name (no dispatch entry). Reads the prefix staged by interpreter__load_kind.

args:
  $1  The inner contract function (e.g. @run)
  $2  The role name (e.g. run)
FUN
__shellops_interpreter__bind_kind() {
  __shellops_interpreter__rehome_fn "$1" "${__shellops_interpreter__load_kind__prefix}_${2//-/_}"
}

:<<'PUB_FUN'
Loads one import provider: an @imports.<id>() function whose inner
@-functions are its roles. Each inner @<role> becomes a plain function named
<id>_<role> (shell_loaders). Providers are called by name, not through the op
dispatcher, so no __dispatch entry is made. A missing required role fails the
load and says which.

Roles: edges, language, and the shell family's loaders and roots. Which are
required depends on whether the plugin names a language, so the registry
checks that; lib/testing/imports/registry.sh says what each means.

args:
  $1  The provider id (e.g. shell)
  $2  The outer @imports.<id> function to invoke
PUB_FUN
interpreter__load_imports() {
  __shellops_interpreter__load_imports__id="$1"

  __shellops_interpreter__load_contract \
    "imports:$1" "imports:$1" "$2" \
    "edges language loaders roots" \
    __shellops_interpreter__bind_imports
}

:<<'FUN'
Binder for import-provider roles: re-homes @<role> to the flat <id>_<role>
name (no dispatch entry). Reads the id staged by interpreter__load_imports.

args:
  $1  The inner contract function (e.g. @edges)
  $2  The role name (e.g. edges)
FUN
__shellops_interpreter__bind_imports() {
  __shellops_interpreter__rehome_fn "$1" "${__shellops_interpreter__load_imports__id}_${2//-/_}"
}

:<<'PUB_FUN'
Loads an @agent.<id>() structural contract, one provider adaptor of the agents
registry: re-homes its inner roles to the flat <id>_<role> functions the
facade in lib/agents/api.sh dispatches to as agents_<role>. Adaptors are
invoked by name, not through the op dispatcher, so no __dispatch entry is
made. Every role is required, and a missing one fails the load naming it;
lib/agents/base.sh says what each role means.
Roles: token_env_name, run, followup, get_run, list_agents, list_runs,
cancel, archive, artifacts, list_models.
args:
  $1  The adaptor id (e.g. cursor)
  $2  The outer @agent.<id> function to invoke
PUB_FUN
interpreter__load_agent() {
  __shellops_interpreter__load_agent__id="${1//-/_}"
  __shellops_interpreter__load_contract \
    "agent:$1" "agent:$1" "$2" \
    "$__shellops_interpreter__AGENT_ROLES" \
    __shellops_interpreter__bind_agent
  __shellops_interpreter__require_roles \
    "interpreter__load_agent: agent $1" \
    "$__shellops_interpreter__load_agent__id" "$__shellops_interpreter__AGENT_ROLES"
}
__shellops_interpreter__AGENT_ROLES="token_env_name run followup get_run list_agents list_runs cancel archive artifacts list_models"

:<<'FUN'
Binder for agent roles: re-homes @<role> to the flat <id>_<role> name (no
dispatch entry), a dash in the id spelled as an underscore. Reads the id
staged by interpreter__load_agent.
args:
  $1  The inner contract function (e.g. @run)
  $2  The role name (e.g. run)
FUN
__shellops_interpreter__bind_agent() {
  __shellops_interpreter__rehome_fn "$1" "${__shellops_interpreter__load_agent__id}_${2//-/_}"
}

:<<'FUN'
Fails, printing "<who> missing required role(s): <roles>" to stderr, when any
of the space-separated <roles> is not defined as <prefix>_<role> after a load.
Succeeds quietly when all are.

args:
  $1  Who is asking, as the error's prefix (e.g. "interpreter__load_check: check indent")
  $2  The function prefix the roles were re-homed under (e.g. indent)
  $3  The space-separated required roles
FUN
__shellops_interpreter__require_roles() {
  __shellops_interpreter__require_roles__missing=$(__shellops_interpreter__missing_roles "$2" "$3")
  @defined "$__shellops_interpreter__require_roles__missing" || return 0

  printf '%s missing required role(s): %s\n' \
    "$1" "$__shellops_interpreter__require_roles__missing" >&2
  return 1
}

:<<'FUN'
Echoes the <roles> not defined as <prefix>_<role> after a load, space-joined
(empty when every one is present).

args:
  $1  The function prefix the roles were re-homed under (e.g. bats)
  $2  The space-separated required roles
FUN
__shellops_interpreter__missing_roles() {
  __shellops_interpreter__missing_roles__missing=""
  for __shellops_interpreter__missing_roles__role in $2; do
    command -v "${1}_${__shellops_interpreter__missing_roles__role}" >/dev/null 2>&1 \
      || __shellops_interpreter__missing_roles__missing="${__shellops_interpreter__missing_roles__missing}${__shellops_interpreter__missing_roles__role} "
  done
  printf '%s' "${__shellops_interpreter__missing_roles__missing% }"
}

:<<'FUN'
The fully-qualified registry name of an op is DERIVED FROM ITS PATH, not from
the inner function name. The handle path mirrors the filesystem under the ops
root, with '/' becoming '.'. This is the bash interpreter's half of the model
documented in planning/docs/stdlib-modules.md; the engine's @use resolution is
the other half and uses the same path<->handle mapping.

Compose an op's FQN from its path relative to <root>:
  <root>/git/current-branch.op.sh  ->  git.current-branch
  <root>/deploy.op.sh              ->  deploy   (top-level, single segment)
FUN
__shellops_interpreter__ops_fqn_for_path() {
  local root="$1"
  local file="$2"
  local rel="${file#"$root"/}"
  local stem="${rel%.op.sh}"

  println "${stem//\//.}"
}

:<<'FUN'
Composes a module type's FQN from the folder its file sits in under <root> and
its local declaration name. The file stem plays no part: a type's FQN does not
depend on which .op.sh file inside the module declares it. A type declared at
the top level takes a bare name.

  <root>/cloud/types.op.sh  @type.datacenter  ->  cloud.datacenter
  <root>/foo.op.sh          @type.bar         ->  bar

args:
  $1  The ops root
  $2  The .op.sh file declaring the type
  $3  The local declaration name (e.g. @type.datacenter)
FUN
__shellops_interpreter__type_fqn_for_path() {
  local root="$1"
  local file="$2"
  local local_name="${3#@type.}"
  local rel="${file#"$root"/}"
  local dir="${rel%/*}"

  if [[ "$dir" == "$rel" ]]; then
    println "$local_name"
    return 0
  fi

  println "${dir//\//.}.${local_name}"
}

:<<'FUN'
Registers every @type.* a freshly-sourced op file declares, each under the FQN
its path derives, and records them as primitives when the tree's kind is
"builtin". The declarations are read off the file itself: a struct scalar's
plugin (lib/structs/types) declares @type.<name> too, so the builtin's outer
function is a redefinition rather than a name the source added, and it is
registered all the same. Succeeds when the file also declared an
@operation.*, which is how interpreter__load_ops_tree learns the file has an
op for it to load.

args:
  $1  The ops root
  $2  The .op.sh file just sourced
  $3  The tree's kind ("builtin" or "module")
  $4  The function names the source added, one per line
FUN
__shellops_interpreter__register_file_types() {
  __shellops_interpreter__register_declared_types "$1" "$2" "$3"
  __shellops_interpreter__declares_op "$4"
}

:<<'FUN'
Registers each @type.* declared at column zero of the op file $2 under the
ops root $1, as a primitive when the tree's kind $3 is "builtin".
FUN
__shellops_interpreter__register_declared_types() {
  local root="$1"
  local file="$2"
  local kind="$3"
  local fn type_fqn

  while IFS= read -r fn; do
    [[ -z "$fn" ]] && continue
    type_fqn=$(__shellops_interpreter__type_fqn_for_path "$root" "$file" "$fn")
    interpreter__load_type "$fn" "$type_fqn"
    [[ "$kind" == builtin ]] && __reg_builtin_types["$type_fqn"]=1
  done <<< "$(grep -oE '^@type\.[^( ]+' "$file" || true)"
}

:<<'FUN'
Succeeds when the function names $1, one per line, hold an @operation.*.
FUN
__shellops_interpreter__declares_op() {
  local fn

  while IFS= read -r fn; do
    case "$fn" in
      @operation.*) return 0 ;;
    esac
  done <<< "$1"

  return 1
}

:<<'PUB_FUN'
Discovers and loads every *.op.sh beneath <root>, in two passes so that every
type is registered before an op body can reference one: the first sources each
file and registers the types it declares, the second loads the operations. Each
is named by the FQN its file's path derives.

Discovery globs *.op.sh rather than gating on the api.sh module marker lib/
uses; planning/docs/stdlib-modules.md sets out how the two relate.

args:
  $1  The ops root
  $2  The tree's kind: "builtin" for the global builtins/ tree, whose types
      register as primitives, or "module" (the default, e.g. lib/), whose types
      register as module types. Ops are authored the same way in either tree.
PUB_FUN
interpreter__load_ops_tree() {
  local root="$1"
  local kind="${2:-module}"
  local file
  local before
  local after
  local new_fns
  local op_files=()

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    before=$(__shellops_interpreter__snap)
    # shellcheck disable=SC1090
    source "$file"
    after=$(__shellops_interpreter__snap)
    new_fns=$(__shellops_interpreter__discover_new "$before" "$after")

    if __shellops_interpreter__register_file_types "$root" "$file" "$kind" "$new_fns"; then
      op_files+=("$file")
    fi
  done < <(find "$root" -name '*.op.sh' | sort)

  for file in ${op_files[@]+"${op_files[@]}"}; do
    local fqn stem outer
    fqn=$(__shellops_interpreter__ops_fqn_for_path "$root" "$file")
    stem="${file##*/}"
    outer="@operation.${stem%.op.sh}"
    interpreter__load_op "$fqn" "$outer"
  done
}
