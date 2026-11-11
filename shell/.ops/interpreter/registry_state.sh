# shellcheck shell=bash

# Declared global (-g) so the registry survives being sourced from inside a
# function (e.g. a bats setup()), not just at a script's top level.
declare -gA __reg_inputs
declare -gA __reg_outputs
declare -gA __reg_notes
declare -gA __reg_contracts
declare -gA __reg_infix
declare -gA __reg_precedence
declare -gA __reg_symbol
declare -gA __reg_builtin_types
declare -gA __dispatch
declare -gA __in_values
declare -gA __type_validators
declare -gA __type_defaults

__cur_op=""
__phase=""  # "register" or "dispatch"
__current_result='{}'
__result_owner_subshell=0
