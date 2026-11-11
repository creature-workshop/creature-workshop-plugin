#!/bin/sh

: <<'MODULE'
Section-aware TOML read/write primitives.

Not a full TOML parser — handles the flat key-value patterns common in
Cargo.toml and similar configuration files. Operates on files directly
with atomic temp-file-then-mv writes.
MODULE

__toml__is_header() {
  case "$1" in
    "["*) return 0 ;;
    *) return 1 ;;
  esac
}

__toml__key_matches() {
  println "$1" | grep -q "^[[:space:]]*${2}[[:space:]]*="
}

__toml__str_contains() {
  case "$1" in
    *"$2"*) return 0 ;;
    *)      return 1 ;;
  esac
}

: <<'FUN'
True when the inline table in $1 assigns a field named $2. A field whose own
name merely contains $2 does not answer for it, so "subversion" is not a match
for "version".
FUN
__toml__inline_has_field() {
  println "$1" | grep -q "[{,][[:space:]]*${2}[[:space:]]*="
}

__toml__unquote_value() {
  __toml__unquote_value__raw="$1"
  __toml__unquote_value__raw="${__toml__unquote_value__raw#\"}"
  __toml__unquote_value__raw="${__toml__unquote_value__raw%\"}"
  printf '%s' "$__toml__unquote_value__raw"
}

: <<'FUN'
Prints the value a TOML key line assigns, still quoted, with the whitespace
around it trimmed. TOML leaves the spacing around the `=` up to the author, so
a line separates its key and value however it likes.

  __toml__line_value 'version   = "1.2.3"'  ->  "1.2.3"
FUN
__toml__line_value() {
  printf '%s' "${1#*=}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

__toml__str_replace_all__step() {
  __toml__STR_REPLACE_ALL_RESULT="${__toml__STR_REPLACE_ALL_RESULT}${__toml__STR_REPLACE_ALL_TEXT%%"$__toml__str_replace_all__old"*}${__toml__str_replace_all__new}"
  __toml__STR_REPLACE_ALL_TEXT="${__toml__STR_REPLACE_ALL_TEXT#*"$__toml__str_replace_all__old"}"
}

__toml__str_replace_all() {
  __toml__STR_REPLACE_ALL_TEXT="$1"
  __toml__str_replace_all__old="$2"
  __toml__str_replace_all__new="$3"
  __toml__STR_REPLACE_ALL_RESULT=""

  while __toml__str_contains "$__toml__STR_REPLACE_ALL_TEXT" "$__toml__str_replace_all__old"; do
    __toml__str_replace_all__step
  done

  printf '%s' "${__toml__STR_REPLACE_ALL_RESULT}${__toml__STR_REPLACE_ALL_TEXT}"
}

: <<'FUN'
Resolves dotted section notation into the actual section header and key
name present in the file. TOML allows "workspace.package" to appear as
either an explicit [workspace.package] header or as dotted keys under
[workspace] (e.g. package.version = "...").

If the section contains a dot and no matching [section] header exists,
splits on the last dot: parent becomes the section, child.key becomes the
effective key. Output: "section key" (space-separated).
FUN
__toml__resolve_dotted__as_nested_key() {
  __toml__RESOLVE_DOTTED_PARENT="${__toml__resolve_dotted__section%.*}"
  __toml__RESOLVE_DOTTED_CHILD="${__toml__resolve_dotted__section##*.}"
  echo "${__toml__RESOLVE_DOTTED_PARENT}" "${__toml__RESOLVE_DOTTED_CHILD}.${__toml__resolve_dotted__key}"
}

__toml__resolve_dotted() {
  __toml__resolve_dotted__file="$1"
  __toml__resolve_dotted__section="$2"
  __toml__resolve_dotted__key="$3"

  if __toml__str_contains "$__toml__resolve_dotted__section" "." \
    && ! grep -q "^\[${__toml__resolve_dotted__section}\]$" "$__toml__resolve_dotted__file" 2>/dev/null; then
    __toml__resolve_dotted__as_nested_key
    return
  fi

  echo "${__toml__resolve_dotted__section}" "${__toml__resolve_dotted__key}"
}

__toml__append__on_leave_section() {
  if ! $__toml__APPEND_APPENDED; then
    echo "${__toml__APPEND_KEY} = ${__toml__APPEND_VALUE}"
    __toml__APPEND_APPENDED=true
  fi
  __toml__APPEND_IN_SECTION=false
}

__toml__append_to_section() {
  __toml__APPEND_FILE="$1"
  __toml__APPEND_SECTION="$2"
  __toml__APPEND_KEY="$3"
  __toml__APPEND_VALUE="$4"
  __toml__APPEND_TEMP_FILE="${__toml__APPEND_FILE}.tmp"
  __toml__APPEND_IN_SECTION=false
  __toml__APPEND_APPENDED=false

  while IFS= read -r __toml__APPEND_LINE; do
    if [ "$__toml__APPEND_LINE" = "[${__toml__APPEND_SECTION}]" ]; then
      __toml__APPEND_IN_SECTION=true
      echo "$__toml__APPEND_LINE"
      continue
    elif $__toml__APPEND_IN_SECTION && __toml__is_header "$__toml__APPEND_LINE"; then
      __toml__append__on_leave_section
    fi
    echo "$__toml__APPEND_LINE"
  done < "$__toml__APPEND_FILE" > "$__toml__APPEND_TEMP_FILE"

  if $__toml__APPEND_IN_SECTION && ! $__toml__APPEND_APPENDED; then
    echo "${__toml__APPEND_KEY} = ${__toml__APPEND_VALUE}" >> "$__toml__APPEND_TEMP_FILE"
  fi

  if ! $__toml__APPEND_APPENDED && ! $__toml__APPEND_IN_SECTION; then
    printf '\n[%s]\n%s = %s\n' "$__toml__APPEND_SECTION" "$__toml__APPEND_KEY" "$__toml__APPEND_VALUE" >> "$__toml__APPEND_TEMP_FILE"
  fi

  mv "$__toml__APPEND_TEMP_FILE" "$__toml__APPEND_FILE"
}

__toml__update_key_in_file() {
  __toml__UPDATE_FILE="$1"
  __toml__UPDATE_SECTION="$2"
  __toml__UPDATE_KEY="$3"
  __toml__UPDATE_VALUE="$4"
  __toml__UPDATE_TEMP_FILE="${__toml__UPDATE_FILE}.tmp"
  __toml__UPDATE_IN_SECTION=false
  __toml__UPDATE_REPLACED=false

  while IFS= read -r __toml__UPDATE_LINE; do
    if [ "$__toml__UPDATE_LINE" = "[${__toml__UPDATE_SECTION}]" ]; then
      __toml__UPDATE_IN_SECTION=true
    elif __toml__is_header "$__toml__UPDATE_LINE"; then
      __toml__UPDATE_IN_SECTION=false
    fi

    if $__toml__UPDATE_IN_SECTION && ! $__toml__UPDATE_REPLACED \
      && __toml__key_matches "$__toml__UPDATE_LINE" "$__toml__UPDATE_KEY"; then
      echo "${__toml__UPDATE_KEY} = ${__toml__UPDATE_VALUE}"
      __toml__UPDATE_REPLACED=true
    else
      echo "$__toml__UPDATE_LINE"
    fi
  done < "$__toml__UPDATE_FILE" > "$__toml__UPDATE_TEMP_FILE"
  mv "$__toml__UPDATE_TEMP_FILE" "$__toml__UPDATE_FILE"
}

__toml__replace_value_in_file() {
  __toml__REPLACE_VAL_FILE="$1"
  __toml__REPLACE_VAL_SECTION="$2"
  __toml__REPLACE_VAL_KEY="$3"
  __toml__REPLACE_VAL_OLD="$4"
  __toml__REPLACE_VAL_NEW="$5"
  __toml__REPLACE_VAL_TEMP_FILE="${__toml__REPLACE_VAL_FILE}.tmp"
  __toml__REPLACE_VAL_IN_SECTION=false

  while IFS= read -r __toml__REPLACE_VAL_LINE; do
    if [ "$__toml__REPLACE_VAL_LINE" = "[${__toml__REPLACE_VAL_SECTION}]" ]; then
      __toml__REPLACE_VAL_IN_SECTION=true
    elif __toml__is_header "$__toml__REPLACE_VAL_LINE"; then
      __toml__REPLACE_VAL_IN_SECTION=false
    fi

    if $__toml__REPLACE_VAL_IN_SECTION \
      && __toml__key_matches "$__toml__REPLACE_VAL_LINE" "$__toml__REPLACE_VAL_KEY" \
      && __toml__str_contains "$__toml__REPLACE_VAL_LINE" "$__toml__REPLACE_VAL_OLD"; then
      __toml__REPLACE_VAL_LINE="$(__toml__str_replace_all "$__toml__REPLACE_VAL_LINE" "$__toml__REPLACE_VAL_OLD" "$__toml__REPLACE_VAL_NEW")"
    fi

    echo "$__toml__REPLACE_VAL_LINE"
  done < "$__toml__REPLACE_VAL_FILE" > "$__toml__REPLACE_VAL_TEMP_FILE"
  mv "$__toml__REPLACE_VAL_TEMP_FILE" "$__toml__REPLACE_VAL_FILE"
}

__toml__get__scan_file() {
  __toml__GET_IN_SECTION=false

  while IFS= read -r __toml__GET_LINE; do
    if [ "$__toml__GET_LINE" = "[${__toml__get__section}]" ]; then
      __toml__GET_IN_SECTION=true
    elif __toml__is_header "$__toml__GET_LINE"; then
      $__toml__GET_IN_SECTION && return
      __toml__GET_IN_SECTION=false
    elif $__toml__GET_IN_SECTION && __toml__key_matches "$__toml__GET_LINE" "$__toml__get__key"; then
      __toml__GET_VALUE="$(__toml__unquote_value "$(__toml__line_value "$__toml__GET_LINE")")"
      echo "$__toml__GET_VALUE"
      return
    fi
  done < "$__toml__get__file"
}

__toml__has_key__scan_file() {
  __toml__HAS_KEY_IN_SECTION=false

  while IFS= read -r __toml__HAS_KEY_LINE; do
    if [ "$__toml__HAS_KEY_LINE" = "[${__toml__has_key__section}]" ]; then
      __toml__HAS_KEY_IN_SECTION=true
    elif __toml__is_header "$__toml__HAS_KEY_LINE"; then
      $__toml__HAS_KEY_IN_SECTION && return 1
      __toml__HAS_KEY_IN_SECTION=false
    elif $__toml__HAS_KEY_IN_SECTION && __toml__key_matches "$__toml__HAS_KEY_LINE" "$__toml__has_key__key"; then
      return 0
    fi
  done < "$__toml__has_key__file"

  return 1
}

__toml__inline_set__replace_field() {
  echo "$__toml__inline_set__line" \
    | sed -E "s/([{,][[:space:]]*)${__toml__inline_set__field}[[:space:]]*=[[:space:]]*\"[^\"]*\"/\\1${__toml__inline_set__field} = ${__toml__inline_set__value}/"
}

__toml__inline_set__insert_field() {
  if printf '%s\n' "$__toml__inline_set__line" | grep -q '{[[:space:]]*}'; then
    echo "$__toml__inline_set__line" \
      | sed -E "s/\{[[:space:]]*\}/{ ${__toml__inline_set__field} = ${__toml__inline_set__value} }/"
  else
    echo "$__toml__inline_set__line" \
      | sed -E "s/[[:space:]]*\}/, ${__toml__inline_set__field} = ${__toml__inline_set__value} }/"
  fi
}

__toml__inline_remove__strip_field() {
  echo "$__toml__inline_remove__line" \
    | sed -E "s/,[[:space:]]*${__toml__inline_remove__field}[[:space:]]*=[[:space:]]*\"[^\"]*\"//; s/(\{[[:space:]]*)${__toml__inline_remove__field}[[:space:]]*=[[:space:]]*\"[^\"]*\"[[:space:]]*(,[[:space:]]*)*/\\1/"
}

: <<'PUB_FUN'
Reads a value from a [section] by key name.
Returns the raw value (unquoted for strings, as-is for booleans/numbers).
Returns empty string if not found.

  toml__get "Cargo.toml" "package" "version"
  toml__get "Cargo.toml" "workspace.package" "edition"
PUB_FUN
toml__get() {
  __toml__get__file="$1"
  __toml__get__section="$2"
  __toml__get__key="$3"

  __toml__get__resolved="$(__toml__resolve_dotted "$__toml__get__file" "$__toml__get__section" "$__toml__get__key")"
  __toml__get__section="${__toml__get__resolved%% *}"
  __toml__get__key="${__toml__get__resolved#* }"

  __toml__get__scan_file
}

: <<'PUB_FUN'
Sets a key in a section. Updates if exists, appends before the next section
header if not. Creates the section if it doesn't exist.

  toml__set "Cargo.toml" "package" "version" '"1.2.3"'
PUB_FUN
toml__set() {
  __toml__set__file="$1"
  __toml__set__section="$2"
  __toml__set__key="$3"
  __toml__set__value="$4"

  __toml__set__resolved="$(__toml__resolve_dotted "$__toml__set__file" "$__toml__set__section" "$__toml__set__key")"
  __toml__set__section="${__toml__set__resolved%% *}"
  __toml__set__key="${__toml__set__resolved#* }"

  if ! toml__has_key "$__toml__set__file" "$__toml__set__section" "$__toml__set__key"; then
    __toml__append_to_section "$__toml__set__file" "$__toml__set__section" "$__toml__set__key" "$__toml__set__value"
    return
  fi

  __toml__update_key_in_file "$__toml__set__file" "$__toml__set__section" "$__toml__set__key" "$__toml__set__value"
}

: <<'PUB_FUN'
Returns 0 if key exists in section, 1 otherwise.

  toml__has_key "Cargo.toml" "package" "version"
PUB_FUN
toml__has_key() {
  __toml__has_key__file="$1"
  __toml__has_key__section="$2"
  __toml__has_key__key="$3"

  __toml__has_key__resolved="$(__toml__resolve_dotted "$__toml__has_key__file" "$__toml__has_key__section" "$__toml__has_key__key")"
  __toml__has_key__section="${__toml__has_key__resolved%% *}"
  __toml__has_key__key="${__toml__has_key__resolved#* }"

  __toml__has_key__scan_file
}

: <<'PUB_FUN'
Targeted replacement of a specific value for a key within a section.
Only replaces if the current value matches $old.

  toml__replace "Cargo.toml" "workspace.package" "version" "1.0.0" "2.0.0"
PUB_FUN
toml__replace() {
  __toml__replace__file="$1"
  __toml__replace__section="$2"
  __toml__replace__key="$3"
  __toml__replace__old="$4"
  __toml__replace__new="$5"

  __toml__replace__resolved="$(__toml__resolve_dotted "$__toml__replace__file" "$__toml__replace__section" "$__toml__replace__key")"
  __toml__replace__section="${__toml__replace__resolved%% *}"
  __toml__replace__key="${__toml__replace__resolved#* }"

  __toml__replace_value_in_file "$__toml__replace__file" "$__toml__replace__section" "$__toml__replace__key" "$__toml__replace__old" "$__toml__replace__new"
}

: <<'PUB_FUN'
Sets a field within a TOML inline table on a single line.
If the field exists, replaces its value. If not, inserts before the closing brace.
Returns the modified line on stdout.

  toml__inline_set 'foo = { path = "bar", version = "=1.0" }' "version" '"=2.0"'
  toml__inline_set 'foo = { path = "bar" }' "version" '"=2.0"'
PUB_FUN
toml__inline_set() {
  __toml__inline_set__line="$1"
  __toml__inline_set__field="$2"
  __toml__inline_set__value="$3"

  if __toml__inline_has_field "$__toml__inline_set__line" "$__toml__inline_set__field"; then
    __toml__inline_set__replace_field
  else
    __toml__inline_set__insert_field
  fi
}

: <<'PUB_FUN'
Removes a field from a TOML inline table on a single line.
Handles leading comma (`, field = "val"`) and trailing comma (`field = "val", `).
No-op if the field is not present. Returns the modified line on stdout.

  toml__inline_remove 'foo = { path = "bar", registry = "internal" }' "registry"
  # → 'foo = { path = "bar" }'
PUB_FUN
toml__inline_remove() {
  __toml__inline_remove__line="$1"
  __toml__inline_remove__field="$2"

  if __toml__inline_has_field "$__toml__inline_remove__line" "$__toml__inline_remove__field"; then
    __toml__inline_remove__strip_field
  else
    echo "$__toml__inline_remove__line"
  fi
}
