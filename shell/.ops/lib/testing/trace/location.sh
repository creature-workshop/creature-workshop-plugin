#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/git/notes.sh" \
  "$SHELLOPS_DIR/lib/git/remotes.sh" \
  "$SHELLOPS_DIR/lib/time/api.sh"

: <<'MODULE'
Where the trace map lives: in git, as a note on the commit it was recorded
at, under a notes ref of its own that a traced run pushes and a review
pipeline fetches; and in a directory under the tree, where a run writes it
first and a map recorded off any commit stays. A run keeps the map in both
places after every file it traces, so a run cut short leaves the map it
had. The newest map is the one noted on the head's own history, and the
directory answers only when no note does. Every map is held to one schema
on both sides.
MODULE

__testing__trace__SCHEMA="$SHELLOPS_DIR/schema/testing-trace.schema.json"

: <<'CONST'
The name of the directory maps live in, by which a map is recognised
wherever a job's tree put that directory.
CONST
__testing__trace__DIR_NAME="testing-trace"

: <<'CONST'
The notes ref a map is kept under in git, one note per commit a map was
recorded at.
CONST
__testing__trace__NOTES_REF="refs/notes/testing-trace"

# CONST: How old a map may be and still be selected by, in days.
__testing__trace__MAP_AGE_DAYS=7

: <<'PUB_FUN'
The directory maps are written to and read from. Defaults under .ops, the
project-root home for what shellops generates; TESTING_TRACE_DIR points it
somewhere else, a scratch directory holding a map someone downloaded.

Usage: testing__trace__dir
PUB_FUN
testing__trace__dir() {
  println "${TESTING_TRACE_DIR:-$PROJ/.ops/$__testing__trace__DIR_NAME}"
}

: <<'PUB_FUN'
Prints the notes ref maps are kept under in git.

Usage: testing__trace__notes_ref   # -> refs/notes/testing-trace
PUB_FUN
testing__trace__notes_ref() {
  println "$__testing__trace__NOTES_REF"
}

: <<'FUN'
Prints true when <map> satisfies the map schema, false when it does not.
The validator's own errors go to stderr either way.

args:
  $1  The map
FUN
__testing__trace__valid() {
  @succeeds __testing__trace__valid__out @validate "$1" "$__testing__trace__SCHEMA"
  println "$__testing__trace__valid__out"
}

: <<'FUN'
Fails, saying so, when <map> does not satisfy the map schema; the verb names
what the caller was about to do with it.

  __testing__trace__refuse_invalid "$map" note

args:
  $1  The map
  $2  The verb: write, note or keep
FUN
__testing__trace__refuse_invalid() {
  if @is_true "$(__testing__trace__valid "$1")"; then
    return 0
  fi
  error "testing/trace: refusing to $2 a map the schema rejects (errors above)."
  return 1
}

: <<'PUB_FUN'
Prints the map at <path>, and returns non-zero without printing when the
file does not parse or the schema rejects it.

args:
  $1  The map file

Usage: testing__trace__read <path>
PUB_FUN
testing__trace__read() {
  @load __testing__trace__read__out "$1" "$__testing__trace__SCHEMA" 2>/dev/null || return 1
  println "$__testing__trace__read__out"
}

: <<'FUN'
The map file's name: when the run was recorded, then the commit it ran at
or the process id outside CI, so a directory sorts by recording and two
maps of one commit cannot collide.

    __testing__trace__filename 2026-09-18T20:00:00Z 9fa43442  ->  20260918T200000Z-9fa43442.json

args:
  $1  The recording timestamp
  $2  The commit, or empty outside CI
FUN
__testing__trace__filename() {
  __testing__trace__filename__stamp="$(printf '%s' "$1" | tr -d ':-')"
  __testing__trace__filename__id="${2:-$$}"
  printf '%s-%s.json\n' \
    "$__testing__trace__filename__stamp" \
    "$(printf '%s' "$__testing__trace__filename__id" | cut -c1-8)"
}

: <<'PUB_FUN'
The map files in the map directory, one path per line, oldest first. No
maps is no output.

Usage: testing__trace__map_files
PUB_FUN
testing__trace__map_files() {
  __testing__trace__map_files__dir="$(testing__trace__dir)"
  (
    cd "$__testing__trace__map_files__dir" 2>/dev/null || exit 0
    set +f
    for __testing__trace__map_files__f in *.json; do
      [ -f "$__testing__trace__map_files__f" ] \
        && printf '%s/%s\n' "$__testing__trace__map_files__dir" "$__testing__trace__map_files__f"
    done
  ) | sort
  # A directory holding no *.json is a clean empty result, not a failure: the
  # unmatched glob's [ -f ] test would otherwise leak rc=1 to a `set -e` caller.
  return 0
}

: <<'PUB_FUN'
Prints the map noted on the newest commit of the checked-out head's history
that carries one, or nothing: when no commit on that history carries a
note, when the notes ref has not been fetched, or when $PROJ is not a
repository. A note the schema rejects is nothing, with a warning.

Usage: map="$(testing__trace__noted_map)"
PUB_FUN
testing__trace__noted_map() {
  __testing__trace__noted_map__commit="$(git__notes__newest "$__testing__trace__NOTES_REF" HEAD)" || return 0
  @defined "$__testing__trace__noted_map__commit" || return 0

  __testing__trace__noted_map__file="$(mktemp)" || return 1
  git__notes__read "$__testing__trace__NOTES_REF" "$__testing__trace__noted_map__commit" \
    > "$__testing__trace__noted_map__file"
  if ! testing__trace__read "$__testing__trace__noted_map__file"; then
    warn "testing/trace: the map noted on $__testing__trace__noted_map__commit does not read; skipping it"
  fi
  rm -f "$__testing__trace__noted_map__file"
}

: <<'PUB_FUN'
Prints the newest map there is: the one noted on the head's history, else
the newest the directory holds that the schema accepts, else nothing. A
directory map that does not read is skipped with a warning rather than
taken as the newest.

Usage: map="$(testing__trace__latest_map)"
PUB_FUN
testing__trace__latest_map() {
  __testing__trace__latest_map__noted="$(testing__trace__noted_map)" || return 1
  if @defined "$__testing__trace__latest_map__noted"; then
    println "$__testing__trace__latest_map__noted"
    return 0
  fi
  __testing__trace__latest_dir_map
}

: <<'FUN'
Prints the newest map the directory holds that the schema accepts, or
nothing when it holds none, skipping one that does not read with a warning.

Usage: __testing__trace__latest_dir_map
FUN
__testing__trace__latest_dir_map() {
  __testing__trace__latest_dir_map__files="$(testing__trace__map_files | sort -r)"
  @defined "$__testing__trace__latest_dir_map__files" || return 0

  println "$__testing__trace__latest_dir_map__files" | {
    while IFS= read -r __testing__trace__latest_dir_map__file; do
      @defined "$__testing__trace__latest_dir_map__file" || continue
      if testing__trace__read "$__testing__trace__latest_dir_map__file"; then
        exit 0
      fi
      warn "testing/trace: skipping unreadable map $__testing__trace__latest_dir_map__file"
    done
    exit 0
  }
}

: <<'PUB_FUN'
Prints the file <map> is written as: under the map directory, named for
when and where it was recorded, so every write of one run's map lands on
one file.

  testing__trace__map_path "$map"  ->  /p/.ops/testing-trace/20260918T200000Z-9fa43442.json

args:
  $1  The map (from testing__trace__map)

Usage: testing__trace__map_path "$map"
PUB_FUN
testing__trace__map_path() {
  @get __testing__trace__map_path__get_1 "$1" '.recorded_at'
  @get __testing__trace__map_path__get_2 "$1" '.commit' ''
  __testing__trace__map_path__name="$(__testing__trace__filename \
    "$__testing__trace__map_path__get_1" \
    "$__testing__trace__map_path__get_2"
  )"
  printf '%s/%s\n' "$(testing__trace__dir)" "$__testing__trace__map_path__name"
}

: <<'PUB_FUN'
Writes <map> to the map directory and prints the file it wrote. Refuses a
map the schema rejects, and fails when the directory cannot be written:
unlike a run's record, a map nobody can read is the whole result of the run
that made it.

args:
  $1  The map (from testing__trace__map)

Usage: testing__trace__map_emit "$map"
PUB_FUN
testing__trace__map_emit() {
  __testing__trace__refuse_invalid "$1" write || return 1
  __testing__trace__map_emit__file="$(__testing__trace__write_file "$1")" || return 1
  log "testing/trace: wrote $__testing__trace__map_emit__file"
  println "$__testing__trace__map_emit__file"
}

: <<'PUB_FUN'
Keeps <map> as the result of the run so far: written to the map directory,
and noted on the commit it names when it names one. Quiet, since a run
calls it after every file it traces. Refuses a map the schema rejects,
leaving what was kept before it standing, and fails when either write
does.

args:
  $1  The map (from testing__trace__map)

Usage: testing__trace__keep "$map"
PUB_FUN
testing__trace__keep() {
  __testing__trace__refuse_invalid "$1" keep || return 1
  __testing__trace__write_file "$1" > /dev/null || return 1

  @get __testing__trace__keep__commit "$1" '.commit' ''
  if ! @defined "$__testing__trace__keep__commit"; then
    return 0
  fi
  __testing__trace__write_note "$1" "$__testing__trace__keep__commit"
}

: <<'FUN'
Writes <map> as its file under the map directory, whole or not at all: a
reader never meets a half-written map. Prints the file. Fails when the
directory cannot be written.

args:
  $1  The map
FUN
__testing__trace__write_file() {
  __testing__trace__write_file__file="$(testing__trace__map_path "$1")"
  __testing__trace__write_file__dir="$(dirname -- "$__testing__trace__write_file__file")"
  mkdir -p "$__testing__trace__write_file__dir" || return 1

  __testing__trace__write_file__part="$(mktemp "$__testing__trace__write_file__dir/.map.XXXXXX")" || return 1
  println "$1" > "$__testing__trace__write_file__part" || return 1
  mv -f "$__testing__trace__write_file__part" "$__testing__trace__write_file__file" || return 1
  println "$__testing__trace__write_file__file"
}

: <<'PUB_FUN'
Attaches <map> to the commit it was recorded at as its note under the notes
ref, replacing the note that commit carried, and prints the commit. Refuses
a map the schema rejects and one that names no commit, since a note has
nowhere to go. Pushing the ref is the caller's, so a run off CI keeps its
note local.

args:
  $1  The map (from testing__trace__map)

Usage: testing__trace__note_emit "$map"
PUB_FUN
testing__trace__note_emit() {
  __testing__trace__refuse_invalid "$1" note || return 1
  __testing__trace__note_emit__commit="$(__testing__trace__note_commit "$1")" || return 1
  __testing__trace__write_note "$1" "$__testing__trace__note_emit__commit" || return 1
  log "testing/trace: noted the map on $__testing__trace__note_emit__commit under $__testing__trace__NOTES_REF"
  println "$__testing__trace__note_emit__commit"
}

: <<'FUN'
Prints the commit <map> was recorded at; fails, saying so, when the map
names none.

args:
  $1  The map
FUN
__testing__trace__note_commit() {
  @get __testing__trace__note_commit__commit "$1" '.commit' ''
  if ! @defined "$__testing__trace__note_commit__commit"; then
    error "testing/trace: refusing to note a map that names no commit."
    return 1
  fi
  println "$__testing__trace__note_commit__commit"
}

: <<'FUN'
Writes <map> as the note on <commit> under the notes ref, through a file
that lives only as long as the write. Fails, saying so, when git refuses.

args:
  $1  The map
  $2  The commit
FUN
__testing__trace__write_note() {
  __testing__trace__write_note__map="$1"
  __testing__trace__write_note__commit="$2"

  __testing__trace__write_note__file="$(mktemp)" || return 1
  @dump __testing__trace__write_note__out "$__testing__trace__write_note__map"
  println "$__testing__trace__write_note__out" > "$__testing__trace__write_note__file"

  __testing__trace__write_note__status=0
  git__notes__write \
    "$__testing__trace__NOTES_REF" \
    "$__testing__trace__write_note__commit" \
    "$__testing__trace__write_note__file" \
    || __testing__trace__write_note__status=$?
  rm -f "$__testing__trace__write_note__file"

  if [ "$__testing__trace__write_note__status" -ne 0 ]; then
    error "testing/trace: could not note the map on $__testing__trace__write_note__commit."
    return 1
  fi
}

: <<'PUB_FUN'
Prints how many days old a map may be and still be selected by.

  testing__trace__map_age_days   ->  7

Usage: testing__trace__map_age_days
PUB_FUN
testing__trace__map_age_days() {
  println "$__testing__trace__MAP_AGE_DAYS"
}

: <<'PUB_FUN'
Prints the cutoff a map must have been recorded at or after to be selected
by: the age limit's number of days ago, as a UTC timestamp.

  testing__trace__map_cutoff   ->  2026-10-07T23:52:13Z

Usage: testing__trace__map_cutoff
PUB_FUN
testing__trace__map_cutoff() {
  time__utc_timestamp_days_ago "$__testing__trace__MAP_AGE_DAYS"
}

: <<'PUB_FUN'
Makes sure the clone's history reaches back to the map cutoff, so that a
walk from the head meets every map the selector may select by. A shallow
clone is deepened from <remote>, origin by default; a full clone is left
as it is; a remote that cannot be asked leaves the clone as it was.

Usage: testing__trace__history_fetch [remote]
PUB_FUN
testing__trace__history_fetch() {
  git__remotes__ensure_history_since "$(testing__trace__map_cutoff)" "${1:-origin}"
}

: <<'PUB_FUN'
Fetches the notes ref from the remote <remote> (origin by default) into
this clone, so the maps recorded elsewhere are readable here. A remote that
holds no notes yet is nothing to fetch; a remote that cannot be asked is a
failure.

Usage: testing__trace__notes_fetch [remote]
PUB_FUN
testing__trace__notes_fetch() {
  __testing__trace__notes_fetch__remote="${1:-origin}"
  __testing__trace__notes_fetch__held="$(git__remotes__has_ref \
    "$__testing__trace__notes_fetch__remote" \
    "$__testing__trace__NOTES_REF"
  )" || return 1
  if @is_false "$__testing__trace__notes_fetch__held"; then
    return 0
  fi
  git__remotes__fetch_ref "$__testing__trace__notes_fetch__remote" "$__testing__trace__NOTES_REF"
}

: <<'PUB_FUN'
Pushes the notes ref to the remote <remote> (origin by default), so the maps
this clone noted reach every clone. A clone that holds no notes has nothing
to push, and that is not a failure. The push fails when the remote refuses
it, and when git cannot read the clone, since the clone may hold notes that
git cannot show.

Usage: testing__trace__notes_push [remote]
PUB_FUN
testing__trace__notes_push() {
  __testing__trace__notes_push__remote="${1:-origin}"
  if @is_false "$(git__repository_readable)"; then
    error "testing/trace: git cannot read this clone, so its notes cannot be pushed."
    return 1
  fi
  if ! git__ref_exists "$__testing__trace__NOTES_REF"; then
    return 0
  fi
  git__remotes__push_ref "$__testing__trace__notes_push__remote" "$__testing__trace__NOTES_REF"
}
