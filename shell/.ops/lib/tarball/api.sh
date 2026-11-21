#!/bin/sh

: <<'MODULE'
Language-agnostic release artifact packaging.

Produces canonically-named tarballs from files or directories.
Callers handle any pre-packaging steps (stripping, signing, etc.).
MODULE

TARBALL_DEFAULT_FORMAT="tar.gz"
TARBALL_ARTIFACTS_SCHEMA="${SHELLOPS_DIR}/lib/tarball/artifacts.schema.json"

# CONST: A newline, to print the paths of the artifacts one on a line.
__tarball__NL='
'

: <<'PUB_FUN'
Validates an artifacts JSON array: checks schema conformance and verifies
that every listed file path exists on disk.

  tarball__validate_artifacts "$json"
  tarball__validate_artifacts "$(cat artifacts.json)"
PUB_FUN
tarball__validate_artifacts() {
  if ! @validate "$1" "$TARBALL_ARTIFACTS_SCHEMA"; then
    return 1
  fi

  @find __tarball__validate_artifacts__missing __tarball__artifact_missing "$1"
  if @defined "$__tarball__validate_artifacts__missing"; then
    @unwrap __tarball__validate_artifacts__unwrap_1 "$__tarball__validate_artifacts__missing"
    error "artifact not found: $__tarball__validate_artifacts__unwrap_1"
    return 1
  fi
}

__tarball__artifact_missing() {
  @unwrap __tarball__artifact_missing__path "$1"
  [ ! -f "$__tarball__artifact_missing__path" ] && [ ! -d "$__tarball__artifact_missing__path" ]
}

: <<'PUB_FUN'
Validates the artifacts JSON array $2 and writes it to <outdir>/artifacts.json,
creating the output directory $1. Prints the validated JSON array to stdout.

  tarball__save_artifacts_json "./dist" "$json"
PUB_FUN
tarball__save_artifacts_json() {
  __tarball__save_artifacts_json__outdir="$1"
  __tarball__save_artifacts_json__json="$2"

  if ! tarball__validate_artifacts "$__tarball__save_artifacts_json__json"; then
    return 1
  fi

  mkdir -p "$__tarball__save_artifacts_json__outdir"
  @dump __tarball__save_artifacts_json__out "$__tarball__save_artifacts_json__json"
  println "$__tarball__save_artifacts_json__out" | tee "${__tarball__save_artifacts_json__outdir}/artifacts.json"
}

: <<'PUB_FUN'
Validates variadic file paths and writes an artifacts.json to the given output
directory. Prints the validated JSON array to stdout.

  tarball__save_artifacts "./dist" path/to/a.tar.gz path/to/b.tar.gz
PUB_FUN
tarball__save_artifacts() {
  __tarball__save_artifacts__outdir="$1"
  shift

  if [ $# -eq 0 ]; then
    error "no artifact paths provided"
    return 1
  fi

  @arr __tarball__save_artifacts__arr_2 "$@"
  tarball__save_artifacts_json "$__tarball__save_artifacts__outdir" "$__tarball__save_artifacts__arr_2"
}

: <<'PUB_FUN'
Reads an artifacts JSON file, validates it, and prints each path line-by-line.

  paths="$(tarball__load_artifacts "./dist/artifacts.json")"
PUB_FUN
tarball__load_artifacts() {
  if [ ! -f "$1" ]; then
    error "artifacts file not found: $1"
    return 1
  fi

  __tarball__load_artifacts__json="$(cat "$1")"

  if ! tarball__validate_artifacts "$__tarball__load_artifacts__json"; then
    error "invalid artifacts file: $1"
    return 1
  fi

  @join __tarball__load_artifacts__out "$__tarball__load_artifacts__json" "$__tarball__NL"
  println "$__tarball__load_artifacts__out"
}

: <<'PUB_FUN'
Prints the paths the artifacts file $1 names as a struct array, and an empty
array when there is no such file: a build with nothing to ship writes none.
A file naming a missing path fails.

  tarball__artifacts_from ./dist/artifacts.json  ->  ["./dist/a.tar.gz"]
  tarball__artifacts_from ./dist/absent.json     ->  []
PUB_FUN
tarball__artifacts_from() {
  if [ ! -f "$1" ]; then
    @arr __tarball__artifacts_from__out
    println "$__tarball__artifacts_from__out"
    return 0
  fi

  __tarball__artifacts_from__paths="$(tarball__load_artifacts "$1")" || return 1
  @split __tarball__artifacts_from__out "$__tarball__artifacts_from__paths"
  println "$__tarball__artifacts_from__out"
}

: <<'PUB_FUN'
Prints the directory the artifacts file $1 sits in, where a build's outputs
and their SHA256SUMS belong, and the working directory when no file was
named.

  tarball__artifacts_dir ./dist/artifacts.json  ->  ./dist
  tarball__artifacts_dir ""                     ->  .
PUB_FUN
tarball__artifacts_dir() {
  if @defined "$1"; then
    dirname "$1"
    return 0
  fi

  printf '.\n'
}

: <<'FUN'
A predicate for @filter: answers false in the variable $1 when the base
name of the path $3 is SHA256SUMS, and true otherwise.

  __tarball__is_not_the_checksums_file yes 0 '"./dist/SHA256SUMS"'  ->  yes=false
FUN
__tarball__is_not_the_checksums_file() {
  @get __tarball__is_not_the_checksums_file__path "$3" '.' ''

  if [ "${__tarball__is_not_the_checksums_file__path##*/}" = SHA256SUMS ]; then
    @false "$1"
  else
    @true "$1"
  fi
}

: <<'PUB_FUN'
Writes <outdir>/SHA256SUMS for the files the struct array $2 names, one line
per file in sha256sum's own form against the file's base name, so a reader
checks a download where it landed, and prints the path written. A SHA256SUMS
already in the array is left out of its own listing.

  tarball__write_checksums ./dist '["./dist/a.tar.gz"]'  ->  ./dist/SHA256SUMS
PUB_FUN
tarball__write_checksums() {
  __tarball__write_checksums__path="$1/SHA256SUMS"
  @filter __tarball__write_checksums__files "$2" __tarball__is_not_the_checksums_file

  mkdir -p "$1"
  @foreach __tarball__checksum_line "$__tarball__write_checksums__files" > "$__tarball__write_checksums__path"
  println "$__tarball__write_checksums__path"
}

: <<'FUN'
@foreach callback: prints the checksum line for the wrapped path $1, the sum
against the base name.
FUN
__tarball__checksum_line() {
  @unwrap __tarball__checksum_line__file "$1"
  __tarball__checksum_line__sum="$(sha256sum "$__tarball__checksum_line__file")"
  __tarball__checksum_line__sum="${__tarball__checksum_line__sum%% *}"

  printf '%s  %s\n' "$__tarball__checksum_line__sum" "${__tarball__checksum_line__file##*/}"
}

: <<'PUB_FUN'
Prints the struct array $2 with the SHA256SUMS written for it in $1 appended;
an empty array stays empty, since there is nothing to sum.

  tarball__with_checksums ./dist '["./dist/a.tar.gz"]'  ->  ["./dist/a.tar.gz","./dist/SHA256SUMS"]
PUB_FUN
tarball__with_checksums() {
  if @len __tarball__with_checksums__len_3 "$2"; [ "$__tarball__with_checksums__len_3" -eq 0 ]; then
    println "$2"
    return 0
  fi

  __tarball__with_checksums__sums="$(tarball__write_checksums "$1" "$2")"
  @wrap __tarball__with_checksums__wrap_4 "$__tarball__with_checksums__sums"
  @push __tarball__with_checksums__out "$2" "$__tarball__with_checksums__wrap_4"
  println "$__tarball__with_checksums__out"
}

: <<'PUB_FUN'
Returns the canonical artifact filename for a release tarball.

  tarball__artifact_name "insights" "1.2.0" "x86_64-apple-darwin"
  # => insights-1.2.0-x86_64-apple-darwin.tar.gz

  tarball__artifact_name "violet" "0.3.1" "aarch64-unknown-linux-gnu" "tar.xz"
  # => violet-0.3.1-aarch64-unknown-linux-gnu.tar.xz
PUB_FUN
tarball__artifact_name() {
  echo "${1}-${2}-${3}.${4:-$TARBALL_DEFAULT_FORMAT}"
}

: <<'PUB_FUN'
Stages a file or directory into the build directory layout expected by
tarball__create_all.

  tarball__stage "/path/to/binary" "$build_dir" "x86_64-apple-darwin"
  tarball__stage "/path/to/dir" "$build_dir" "x86_64-apple-darwin"
PUB_FUN
tarball__stage() {
  mkdir -p "${2}/${3}"

  if [ -d "$1" ]; then
    cp -r "$1" "${2}/${3}/"
  else
    cp "$1" "${2}/${3}/"
  fi
}

: <<'PUB_FUN'
Stages a file or directory for every triple in a JSON array. The
source_callback receives each triple as its first argument, followed by any
extra args, and should echo the path to the artifact to stage.

  tarball__stage_all "$build_dir" "$triples" my_source_callback [extra_args...]
  # callback signature: my_source_callback "x86_64-apple-darwin" [extra_args...] -> echoes path
PUB_FUN
tarball__stage_all() {
  __tarball__stage_all__build_dir="$1"
  __tarball__stage_all__triples="$2"
  __tarball__stage_all__source_callback="$3"
  shift 3
  @foreach __tarball__stage_one "$__tarball__stage_all__triples" "$__tarball__stage_all__build_dir" "$__tarball__stage_all__source_callback" "$@"
}

__tarball__stage_one() {
  @unwrap __tarball__stage_one__triple "$1"
  __tarball__stage_one__build_dir="$2"
  __tarball__stage_one__source_callback="$3"
  shift 3
  __tarball__stage_one__source="$("$__tarball__stage_one__source_callback" "$__tarball__stage_one__triple" "$@")"
  tarball__stage "$__tarball__stage_one__source" "$__tarball__stage_one__build_dir" "$__tarball__stage_one__triple"
}

: <<'PUB_FUN'
Packages a file or directory into a canonically-named tarball.

The tarball is created in outdir. The archived content is placed
under a top-level directory matching the artifact stem (name-version-triple)
so extraction produces a single predictable folder.

  tarball__create "/path/to/binary" "insights" "1.2.0" "x86_64-apple-darwin" "./dist"

Returns the path to the created tarball.
PUB_FUN
tarball__create() {
  __tarball__create__source="$1"
  __tarball__create__name="$2"
  __tarball__create__version="$3"
  __tarball__create__triple="$4"
  __tarball__create__outdir="$5"
  __tarball__create__format="${6:-$TARBALL_DEFAULT_FORMAT}"

  __tarball__create__artifact_name="$(tarball__artifact_name "$__tarball__create__name" "$__tarball__create__version" "$__tarball__create__triple" "$__tarball__create__format")"
  __tarball__create__stem="${__tarball__create__artifact_name%."${__tarball__create__format}"}"

  __tarball__create__staging="$(mktemp -d)"
  mkdir -p "${__tarball__create__staging}/${__tarball__create__stem}"

  if [ -d "$__tarball__create__source" ]; then
    cp -r "$__tarball__create__source"/. "${__tarball__create__staging}/${__tarball__create__stem}/"
  else
    cp "$__tarball__create__source" "${__tarball__create__staging}/${__tarball__create__stem}/"
  fi

  mkdir -p "$__tarball__create__outdir"

  __tarball__create__tar_flag="$(__tarball__compression_flag "$__tarball__create__format")"

  # The tar argv is built in the positional parameters (POSIX sh has no
  # arrays).
  set -- tar -C "$__tarball__create__staging"
  # structs-lint: allow -- the flag is one more tar argument, not a struct array
  @defined "$__tarball__create__tar_flag" && set -- "$@" "$__tarball__create__tar_flag"
  set -- "$@" -cf "${__tarball__create__outdir}/${__tarball__create__artifact_name}" "$__tarball__create__stem"
  "$@"

  rm -rf "$__tarball__create__staging"

  __tarball__create__dest="${__tarball__create__outdir}/${__tarball__create__artifact_name}"
  __tarball__create__size="$(__tarball__human_size "$__tarball__create__dest")"
  log "packaged ${__tarball__create__dest} (${__tarball__create__size})"
  echo "$__tarball__create__dest"
}

__tarball__compression_flag() {
  case "$1" in
    tar.gz)  echo "-z" ;;
    tar.xz)  echo "-J" ;;
    tar.bz2) echo "-j" ;;
    tar)     echo "" ;;
    *)
      error "tarball: unsupported format '$1'"
      return 1
      ;;
  esac
}

: <<'PUB_FUN'
Packages every triple's artifact from a build output directory.

Expects a directory layout where each triple has its own subdirectory
containing the file(s) to package:

  build_output/
    x86_64-apple-darwin/
      mybin
    aarch64-unknown-linux-gnu/
      mybin

  tarball__create_all "./build_output" "mybin" "1.0.0" "./dist"

Creates one tarball per subdirectory. Returns a JSON array of output paths.
PUB_FUN
tarball__create_all() {
  __tarball__create_all__build_dir="$1"
  __tarball__create_all__name="$2"
  __tarball__create_all__version="$3"
  __tarball__create_all__outdir="$4"
  __tarball__create_all__format="${5:-$TARBALL_DEFAULT_FORMAT}"

  @arr __tarball__create_all__results

  for __tarball__create_all__triple_dir in "$__tarball__create_all__build_dir"/*/; do
    [ -d "$__tarball__create_all__triple_dir" ] || continue

    __tarball__create_all__triple="$(basename "$__tarball__create_all__triple_dir")"

    __tarball__create_all__dest="$(tarball__create "$__tarball__create_all__triple_dir" "$__tarball__create_all__name" "$__tarball__create_all__version" "$__tarball__create_all__triple" "$__tarball__create_all__outdir" "$__tarball__create_all__format")"
    @wrap __tarball__create_all__wrap_5 "$__tarball__create_all__dest"
    @push __tarball__create_all__results "$__tarball__create_all__results" '.' "$__tarball__create_all__wrap_5"
  done

  echo "$__tarball__create_all__results"
}

__tarball__human_size() {
  __tarball__human_size__bytes_per_kb=1024
  __tarball__human_size__bytes_per_mb=$(( 1024 * 1024 ))
  __tarball__human_size__bytes_per_gb=$(( 1024 * 1024 * 1024 ))

  if [ ! -f "$1" ]; then
    error "not a file: $1"
    return 1
  fi

  __tarball__human_size__bytes="$(stat --printf='%s' "$1" 2>/dev/null || stat -f '%z' "$1" 2>/dev/null)"

  if [ "$__tarball__human_size__bytes" -ge "$__tarball__human_size__bytes_per_gb" ]; then
    __tarball__fmt_size "$__tarball__human_size__bytes" "$__tarball__human_size__bytes_per_gb" "G"
  elif [ "$__tarball__human_size__bytes" -ge "$__tarball__human_size__bytes_per_mb" ]; then
    __tarball__fmt_size "$__tarball__human_size__bytes" "$__tarball__human_size__bytes_per_mb" "M"
  elif [ "$__tarball__human_size__bytes" -ge "$__tarball__human_size__bytes_per_kb" ]; then
    __tarball__fmt_size "$__tarball__human_size__bytes" "$__tarball__human_size__bytes_per_kb" "K"
  else
    echo "${__tarball__human_size__bytes}B"
  fi
}

__tarball__fmt_size() {
  __tarball__fmt_size__whole=$(( $1 / $2 ))
  __tarball__fmt_size__remainder=$(( ($1 % $2) * 10 / $2 ))
  echo "${__tarball__fmt_size__whole}.${__tarball__fmt_size__remainder}${3}"
}
