#!/bin/sh
# shellcheck disable=SC2034

: <<'MODULE'
API for getting and setting managed information in the project's environment settings
MODULE

__envrc__file="$PROJ/.envrc"
__envrc__slug_begin="@managed:begin"
__envrc__slug_end="@managed:end"
__envrc__schema='{"godot_url":"GODOT_URL","godot_version":"GODOT_VERSION"}'
@obj __envrc__CACHE

: <<'PUB_FUN'
  Gets a particular variable from the project environment

  Usage: envrc__get <key>
PUB_FUN
envrc__get() {
  __envrc__get__key="$1"
  @get __envrc__get__var "$__envrc__schema" ".$__envrc__get__key"

  if [ "$__envrc__get__var" = "null" ]; then
    warn "Unknown project environment key: '$__envrc__get__key'"
    return 1
  fi

  @get __envrc__get__cached "$__envrc__CACHE" ".$__envrc__get__var"
  if [ "$__envrc__get__cached" = "null" ]; then
    __envrc__get__loaded="$(__envrc__load_variables)"
    @get __envrc__get__cached "$__envrc__get__loaded" ".$__envrc__get__var"
    @encode_string __envrc__get__encode_string_1 "$__envrc__get__cached"
    @set __envrc__CACHE "$__envrc__CACHE" ".$__envrc__get__var" "$__envrc__get__encode_string_1"
  fi

  println "$__envrc__get__cached"
}

: <<'PUB_FUN'
  Sets a variable in the project environment.

  Usage: envrc__set <key> <value>
PUB_FUN
envrc__set() {
  __envrc__set__key="$1"
  __envrc__set__value="$2"
  @get __envrc__set__var "$__envrc__schema" ".$__envrc__set__key"

  if [ "$__envrc__set__var" = "null" ]; then
    warn "Unknown project environment key '$__envrc__set__key'"
    return 1
  fi

  __envrc__set__vars="$(__envrc__load_variables)"
  @encode_string __envrc__set__encode_string_2 "$__envrc__set__value"
  @set __envrc__set__vars "$__envrc__set__vars" ".$__envrc__set__var" "$__envrc__set__encode_string_2"
  __envrc__save_variables "$__envrc__set__vars"

  @encode_string __envrc__set__encode_string_3 "$__envrc__set__value"
  @set __envrc__CACHE "$__envrc__CACHE" ".$__envrc__set__var" "$__envrc__set__encode_string_3"
}

__envrc__get_managed_section() {
  __envrc__GMS_CONTENT="$(cat "$__envrc__file")"
  __envrc__GMS_CONTENT="${__envrc__GMS_CONTENT#*"$__envrc__slug_begin"}"
  __envrc__GMS_CONTENT="${__envrc__GMS_CONTENT%%"$__envrc__slug_end"*}"
  println "$__envrc__GMS_CONTENT"
}

__envrc__load_variables() {
  __envrc__LOAD_SECTION="$(__envrc__get_managed_section)"
  @obj __envrc__LOAD_VARS
  @keys __envrc__LOAD_KEY_LIST "$__envrc__schema"
  @len __envrc__LOAD_N "$__envrc__LOAD_KEY_LIST"
  __envrc__LOAD_I=0

  while [ "$__envrc__LOAD_I" -lt "$__envrc__LOAD_N" ]; do
    @get __envrc__LOAD_KEY "$__envrc__LOAD_KEY_LIST" ".[$__envrc__LOAD_I]"
    @get __envrc__LOAD_VAR "$__envrc__schema" ".$__envrc__LOAD_KEY"
    __envrc__LOAD_LINE="$(println "$__envrc__LOAD_SECTION" | grep "${__envrc__LOAD_VAR}=" || true)"

    if ! @defined "$__envrc__LOAD_LINE"; then
      @set __envrc__LOAD_VARS "$__envrc__LOAD_VARS" ".$__envrc__LOAD_VAR" '""'
    else
      __envrc__LOAD_VAL="${__envrc__LOAD_LINE#*=}"
      __envrc__LOAD_VAL="$(printf '%s' "$__envrc__LOAD_VAL" | tr -d '"')"
      @encode_string __envrc__load_variables__encode_string_4 "$__envrc__LOAD_VAL"
      @set __envrc__LOAD_VARS "$__envrc__LOAD_VARS" ".$__envrc__LOAD_VAR" "$__envrc__load_variables__encode_string_4"
    fi

    __envrc__LOAD_I=$((__envrc__LOAD_I + 1))
  done

  println "$__envrc__LOAD_VARS"
}

__envrc__save_variables() {
  __envrc__SAVE_VARS="$1"
  __envrc__SAVE_TMP="$(mktemp)"
  __envrc__SAVE_RANGE="/^# ${__envrc__slug_begin}/,/^# ${__envrc__slug_end}/"
  cp "$__envrc__file" "$__envrc__SAVE_TMP"

  @keys __envrc__SAVE_KEY_LIST "$__envrc__SAVE_VARS"
  @len __envrc__SAVE_N "$__envrc__SAVE_KEY_LIST"
  __envrc__SAVE_I=0

  while [ "$__envrc__SAVE_I" -lt "$__envrc__SAVE_N" ]; do
    @get __envrc__SAVE_VAR "$__envrc__SAVE_KEY_LIST" ".[$__envrc__SAVE_I]"
    @get __envrc__SAVE_VAL "$__envrc__SAVE_VARS" ".$__envrc__SAVE_VAR"

    if __envrc__exists_in_managed_block "$__envrc__SAVE_TMP" "^${__envrc__SAVE_VAR}="; then
      __envrc__SAVE_OLD="^${__envrc__SAVE_VAR}=.*"
      __envrc__SAVE_NEW="${__envrc__SAVE_VAR}=\"${__envrc__SAVE_VAL}\""
      sed -i "${__envrc__SAVE_RANGE}s|$__envrc__SAVE_OLD|$__envrc__SAVE_NEW|" "$__envrc__SAVE_TMP"
    else
      sed -i "/^# ${__envrc__slug_end}/i ${__envrc__SAVE_VAR}=\"${__envrc__SAVE_VAL}\"" "$__envrc__SAVE_TMP"
    fi

    __envrc__SAVE_I=$((__envrc__SAVE_I + 1))
  done

  mv "$__envrc__SAVE_TMP" "$__envrc__file"
}

__envrc__exists_in_managed_block() {
  __envrc__EXISTS_FILE="$1"
  __envrc__EXISTS_PATTERN="$2"
  __envrc__EXISTS_RANGE="/^# ${__envrc__slug_begin}/,/^# ${__envrc__slug_end}/p"
  sed -n "$__envrc__EXISTS_RANGE" "$__envrc__EXISTS_FILE" | grep -q "$__envrc__EXISTS_PATTERN"
}
