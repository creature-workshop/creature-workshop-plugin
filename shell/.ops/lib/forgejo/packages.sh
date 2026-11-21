#!/bin/sh

:<<'FRAGMENT'
The Forgejo generic package registry: files published under an owner by
package name and version, reachable at a plain URL, which is what a Homebrew
formula for a dev or alpha build points at.
FRAGMENT

# CONST: How many files the last forgejo__publish_package_files uploaded.
__forgejo__UPLOADED=0

# CONST: How many files the last forgejo__publish_package_files found in the registry already.
__forgejo__PRESENT=0

:<<'PUB_FUN'
Default options for a generic package file, with the owner from
manifest.json.

Usage: forgejo__new_package_options
PUB_FUN
forgejo__new_package_options() {
  @obj __forgejo__new_package_options__out \
    '.owner'    "$(manifest__get org)" \
    '.package'  "" \
    '.version'  "" \
    '.filename' "" \
    '.filepath' "" \
    '.token'    ""
  println "$__forgejo__new_package_options__out"
}

:<<'PUB_FUN'
Publishes every file the struct array $2 names into the package the options
$1 describe, each under its base name, and prints how many went up and how
many the registry already held. Fails on the first upload the registry
refuses.

  forgejo__publish_package_files "$options" '["./dist/a.tar.gz"]'  ->  {"uploaded":1,"present":0}
PUB_FUN
forgejo__publish_package_files() {
  __forgejo__UPLOADED=0
  __forgejo__PRESENT=0
  @foreach __forgejo__publish_package_file "$2" "$1" || return 1

  @obj __forgejo__publish_package_files__out \
    '.uploaded' "$__forgejo__UPLOADED" \
    '.present'  "$__forgejo__PRESENT"
  println "$__forgejo__publish_package_files__out"
}

:<<'PUB_FUN'
Uploads the file .filepath as .filename into the generic package .package
at .version under .owner, and prints true. Prints false when the registry
already holds a file of that name at that version, which Forgejo refuses
with a 409 and a rerun takes as done. Any other refusal fails with the
request's own message.

Usage: forgejo__upload_package_file "$package_options"
PUB_FUN
forgejo__upload_package_file() {
  __forgejo__package_file_complete "$1" || return 1
  __forgejo__upload_package_file__token="$(__forgejo__validate_token "$1")" || return 1

  @get __forgejo__upload_package_file__get_1 "$1" '.filepath'
  __forgejo__put_package_file \
    "$(__forgejo__package_file_endpoint "$1")" \
    "$__forgejo__upload_package_file__get_1" \
    "$(__forgejo__package_http_opts "$__forgejo__upload_package_file__token")"
}

:<<'FUN'
@foreach callback: uploads the wrapped path $1 with the package options $2
under its base name, and counts it as uploaded or already there.
FUN
__forgejo__publish_package_file() {
  @unwrap __forgejo__publish_package_file__path "$1"
  __forgejo__publish_package_file__name="${__forgejo__publish_package_file__path##*/}"
  @set __forgejo__publish_package_file__options "$2" \
    '.filename' "$__forgejo__publish_package_file__name" \
    '.filepath' "$__forgejo__publish_package_file__path"

  log "Uploading $__forgejo__publish_package_file__name..."
  __forgejo__publish_package_file__uploaded="$(forgejo__upload_package_file "$__forgejo__publish_package_file__options")" || return 1
  if @is_true "$__forgejo__publish_package_file__uploaded"; then
    __forgejo__UPLOADED=$(( __forgejo__UPLOADED + 1 ))
    return 0
  fi

  log "$__forgejo__publish_package_file__name is already in the registry"
  __forgejo__PRESENT=$(( __forgejo__PRESENT + 1 ))
}

:<<'FUN'
Prints the keys the package options $1 leave empty, among filepath,
filename, package and version, with a space between them, and nothing when
all four are set.

  __forgejo__missing_package_fields '{"filepath":"a","filename":"","package":"p"}'
  -> filename version
FUN
__forgejo__missing_package_fields() {
  __forgejo__missing_package_fields__missing=''

  for __forgejo__missing_package_fields__key in filepath filename package version; do
    @get __forgejo__missing_package_fields__value "$1" ".$__forgejo__missing_package_fields__key" ''
    if [ -z "$__forgejo__missing_package_fields__value" ]; then
      __forgejo__missing_package_fields__missing="${__forgejo__missing_package_fields__missing:+$__forgejo__missing_package_fields__missing }$__forgejo__missing_package_fields__key"
    fi
  done

  println "$__forgejo__missing_package_fields__missing"
}

:<<'FUN'
Fails, naming what is missing, when the package options $1 leave the file,
its name, the package or the version empty.
FUN
__forgejo__package_file_complete() {
  __forgejo__package_file_complete__missing="$(__forgejo__missing_package_fields "$1")"
  if @defined "$__forgejo__package_file_complete__missing"; then
    @get __forgejo__package_file_complete__get_2 "$1" '.filename' '<unnamed>'
    error "Incomplete package file: no $__forgejo__package_file_complete__missing for $__forgejo__package_file_complete__get_2"
    return 1
  fi
}

:<<'FUN'
The http options for a package upload with token $1: a PUT of the file's
raw bytes.
FUN
__forgejo__package_http_opts() {
  @set __forgejo__package_http_opts__out "$(__forgejo__http_opts "$1")" \
    '.method'      "PUT" \
    '.upload_mode' "binary"
  println "$__forgejo__package_http_opts__out"
}

:<<'FUN'
Uploads file $2 to $1 with http options $3 and prints true, or false on a
409, the registry saying it already holds the file. Any other refusal fails
with the request's own message. The status is read after the request rather
than inside a substitution of it, since a substitution runs in a subshell
and the status would die there.
FUN
__forgejo__put_package_file() {
  __forgejo__put_package_file__err="$(mktemp)"
  if http__upload "$1" "$2" "$3" \
    > /dev/null \
    2> "$__forgejo__put_package_file__err"
  then
    rm -f "$__forgejo__put_package_file__err"
    @true __forgejo__put_package_file__out
    println "$__forgejo__put_package_file__out"
    return 0
  fi

  __forgejo__put_package_file__status="$(http__last_status)"
  __forgejo__put_package_file__stderr="$(cat "$__forgejo__put_package_file__err")"
  rm -f "$__forgejo__put_package_file__err"
  if [ "$__forgejo__put_package_file__status" = 409 ]; then
    @false __forgejo__put_package_file__out
    println "$__forgejo__put_package_file__out"
    return 0
  fi

  println "$__forgejo__put_package_file__stderr" >&2
  return 1
}
