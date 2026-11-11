#!/bin/sh

import "$SHELLOPS_DIR/lib/self/config.sh"

:<<'MODULE'
API for the manifest "testing" block: the explicit, nested area tree that drives
area-label generation and test selection.

Each area declares its own `source` path (repo-relative) and may nest sub-areas
under `areas`. An area whose only field is its source may be written in shorthand
as that source string ("name": "path"), sugar for {"source": "path"}.
areas__compute_areas flattens that tree to a flat map keyed by the
area's dotted name (parent.child), resolving inheritance top-down: a child
inherits its parent's full_suite and coverage unless it overrides them. The
output feeds the label taxonomy (areas__to_label_items), the resolver, and the
scorecard. There is no filesystem scan -- areas are authored explicitly.
MODULE

:<<'PUB_FUN'
Loads the testing config, resolving it from the first source that applies, in
precedence order: an inline .testing object in manifest.json; a .testing string
naming a testmap file (repo-relative); a sibling testmap.json; otherwise none.
Returns the config object or "null".

Usage: areas__load_areas_config
PUB_FUN
areas__load_areas_config() {
  __areas__load_areas_config__manifest="$(self__config__load manifest)"

  case "$(__areas__testing_kind "$__areas__load_areas_config__manifest")" in
    object) __areas__inline_config "$__areas__load_areas_config__manifest" ;;
    string) __areas__testmap_config "$__areas__load_areas_config__manifest" ;;
    *)      __areas__sibling_config ;;
  esac
}

:<<'FUN'
The inline .testing object as the config.

args:
  $1  The manifest JSON
FUN
__areas__inline_config() {
  @get __areas__inline_config__get_1 "$1" '.testing' 'null'
  @compact __areas__inline_config__out "$__areas__inline_config__get_1"
  println "$__areas__inline_config__out"
}

:<<'FUN'
The config loaded from the testmap file the .testing string names.

args:
  $1  The manifest JSON
FUN
__areas__testmap_config() {
  @get __areas__testmap_config__get_2 "$1" '.testing' ''
  __areas__load_testmap "$__areas__testmap_config__get_2"
}

:<<'FUN'
The config from a sibling testmap file, or "null" when there is none.

Usage: __areas__sibling_config
FUN
__areas__sibling_config() {
  __areas__sibling_config__path="$(__areas__sibling_testmap)"
  if @defined "$__areas__sibling_config__path"; then
    __areas__load_testmap "$__areas__sibling_config__path"
  else
    printf 'null'
  fi
}

:<<'FUN'
The JSON type of the manifest's .testing value -- "object" (an inline block),
"string" (a testmap path), or "null" (absent). Selects areas__load_areas_config's
resolution branch.

args:
  $1  The manifest JSON
FUN
__areas__testing_kind() {
  @typeof __areas__testing_kind__out "$1" '.testing'
  println "$__areas__testing_kind__out"
}

:<<'FUN'
Loads and parses a testmap file at a repo-relative path, returning its config
object. Logs an error and returns "null" when the path names no readable file.
Only JSON is parsed today; other extensions are reserved until shellops gains
their parsers.

args:
  $1  The testmap path, relative to the manifest (PROJ root)
FUN
__areas__load_testmap() {
  __areas__load_testmap__path="$PROJ/$1"
  if [ ! -f "$__areas__load_testmap__path" ]; then
    error "testmap file not found: $1"
    printf 'null'
    return
  fi
  @compact __areas__load_testmap__out "$(cat "$__areas__load_testmap__path")"
  println "$__areas__load_testmap__out"
}

:<<'FUN'
The repo-relative path of a sibling testmap file next to manifest.json, or empty
when none exists. Only testmap.json is recognized today.

Usage: __areas__sibling_testmap
FUN
__areas__sibling_testmap() {
  if [ -f "$PROJ/testmap.json" ]; then
    printf 'testmap.json'
  fi
}

:<<'PUB_FUN'
Prints the struct boolean for whether the repo declares a testing config
(inline, a testmap path, or a sibling testmap file).

Usage: if @is_true "$(areas__has_areas_config)"; then ... fi
PUB_FUN
areas__has_areas_config() {
  @succeeds __areas__has_areas_config__out @defined "$(areas__load_areas_config)"
  println "$__areas__has_areas_config__out"
}

:<<'PUB_FUN'
The repo-relative path of the file that holds the testing config, by the same
precedence areas__load_areas_config uses: manifest.json for an inline .testing object,
the .testing string for a named testmap, the sibling testmap.json, else empty.

Lets callers (e.g. the area/new pr-hygiene gate) tell whether a diff touched the
area mapping.

Usage: areas__config_path
PUB_FUN
areas__config_path() {
  __areas__config_path__manifest="$(self__config__load manifest 2>/dev/null)" || return 0
  @defined "$__areas__config_path__manifest" || return 0

  case "$(__areas__testing_kind "$__areas__config_path__manifest")" in
    object) __areas__inline_config_path ;;
    string) __areas__testmap_config_path "$__areas__config_path__manifest" ;;
    *)      __areas__sibling_testmap ;;
  esac
}

:<<'FUN'
The path of an inline config: manifest.json itself.

Usage: __areas__inline_config_path
FUN
__areas__inline_config_path() {
  printf 'manifest.json'
}

:<<'FUN'
The testmap path the manifest's .testing string names.

args:
  $1  The manifest JSON
FUN
__areas__testmap_config_path() {
  @get __areas__testmap_config_path__out "$1" '.testing' ''
  println "$__areas__testmap_config_path__out"
}

:<<'PUB_FUN'
Computes the canonical area set from a manifest testing config.

Reads testing.areas (the explicit nested tree) and testing.coverage (the default
gate), flattens the tree to a flat map keyed by dotted area name, and resolves
inheritance. A string-shorthand area (a child written as its source string,
"name": "path") is expanded to {source: "path"} before flattening. Each emitted
area carries: paths (a one-element list of its source,
or empty for a virtual area), tests (suite-keyed test globs), inert (true when
the area, or the nearest ancestor that declares tests, declares none), full_suite (a
bool), and coverage (min and mode, present only when an effective gate exists).

args:
  $1  The testing config object (from areas__load_areas_config)
PUB_FUN
areas__compute_areas() {
  @run_awk __areas__compute_areas__out "$SHELLOPS_DIR/lib/areas/compute_areas.awk" "$1" || return 1
  println "$__areas__compute_areas__out"
}

:<<'PUB_FUN'
Converts a canonical area set into the flat name-to-description format that
labels__merged_labels() expects for injection into the area category. The name is the
dotted area name (parent.child); the description is auto-generated from the
area's source path (or marked virtual when it has none).

args:
  $1  The canonical area set (from areas__compute_areas)
PUB_FUN
areas__to_label_items() {
  @entries __areas__to_label_items__entries_4 "$1"
  @obj __areas__to_label_items__obj_5
  @reduce __areas__to_label_items__out __areas__area_to_label_item "$__areas__to_label_items__entries_4" "$__areas__to_label_items__obj_5"
  println "$__areas__to_label_items__out"
}

:<<'FUN'
@reduce callback: one canonical area entry to a dotted-name to description label
item.

args:
  $1  The accumulator (label items object)
  $2  The entry (its key is the dotted area name, its value the area)
FUN
__areas__area_to_label_item() {
  @get __areas__area_to_label_item__name "$2" '.key'
  @get __areas__area_to_label_item__paths "$2" '.value.paths'
  @join __areas__area_to_label_item__joined "$__areas__area_to_label_item__paths" ", "

  if ! @defined "$__areas__area_to_label_item__joined"; then
    __areas__area_to_label_item__desc="Virtual area (no source path)"
  else
    __areas__area_to_label_item__desc="Source: $__areas__area_to_label_item__joined"
  fi

  @set __areas__area_to_label_item__out "$1" ".\"$__areas__area_to_label_item__name\"" "$__areas__area_to_label_item__desc"
  println "$__areas__area_to_label_item__out"
}
