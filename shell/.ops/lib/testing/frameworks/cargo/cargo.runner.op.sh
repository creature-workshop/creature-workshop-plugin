#!/usr/bin/env bash

# Cargo runner plugin for Test Impact Analysis (TIA).

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/cargo/api.sh" \
  "$SHELLOPS_DIR/lib/testing/resolver.sh" \
  "$SHELLOPS_DIR/lib/testing/adapter.sh"

:<<'FUN'
The sorted, unique set of cargo package names owning the given files, as a struct
array; files with no owning package are skipped. A top-level helper shared by the
run_selected role, not a contract role.

args:
  $@  Test file paths, relative to $PROJ
FUN
__testing__frameworks__cargo__packages_for_files() {
  @arr __testing__frameworks__cargo__packages_for_files__acc

  for __testing__frameworks__cargo__packages_for_files__file in "$@"; do
    __testing__frameworks__cargo__packages_for_files__name="$(cargo__package_for_file "$__testing__frameworks__cargo__packages_for_files__file")"
    if @defined "$__testing__frameworks__cargo__packages_for_files__name"; then
      @wrap __testing__frameworks__cargo__packages_for_files__wrap_1 "$__testing__frameworks__cargo__packages_for_files__name"
      @push __testing__frameworks__cargo__packages_for_files__acc "$__testing__frameworks__cargo__packages_for_files__acc" \
        "$__testing__frameworks__cargo__packages_for_files__wrap_1"
    fi
  done

  @unique __testing__frameworks__cargo__packages_for_files__out "$__testing__frameworks__cargo__packages_for_files__acc"
  println "$__testing__frameworks__cargo__packages_for_files__out"
}

:<<'PUB_FUN'
Prints every directory that holds a cargo package, as a struct array of
$PROJ-relative paths. A directory holds a package when git tracks a Cargo.toml
there and that manifest declares a [package] name; a manifest that only
declares [workspace] does not count. A package at the repo root prints as ".".
Crate discovery judges ownership against this set.

For a repo tracking engine/Cargo.toml (workspace only, no [package]),
engine/cache/Cargo.toml, and engine/opgen/Cargo.toml:

  testing__frameworks__cargo__package_roots  ->  ["engine/cache", "engine/opgen"]
PUB_FUN
testing__frameworks__cargo__package_roots() {
  @split __testing__frameworks__cargo__package_roots__manifests "$(__testing__frameworks__cargo__tracked_manifests)"
  @map __testing__frameworks__cargo__package_roots__map_2 __testing__frameworks__cargo__package_root "$__testing__frameworks__cargo__package_roots__manifests"
  @filter __testing__frameworks__cargo__package_roots__out \
    "$__testing__frameworks__cargo__package_roots__map_2" \
    silt__text_is_not . ''
  println "$__testing__frameworks__cargo__package_roots__out"
}

:<<'FUN'
Prints the path of every Cargo.toml that git tracks under $PROJ, one on each
line, and nothing when it tracks none.

  __testing__frameworks__cargo__tracked_manifests  ->  engine/Cargo.toml
                                                       engine/cache/Cargo.toml
FUN
__testing__frameworks__cargo__tracked_manifests() {
  git__tracked_files "$PROJ" \
    | grep -E '(^|/)Cargo\.toml$' \
    || true
}

:<<'FUN'
@map callback: prints the directory of one tracked Cargo.toml when it declares
a [package] name, and "" when it does not. The repo root's own manifest prints
as ".".

args:
  $1  Manifest path (wrapped)
FUN
__testing__frameworks__cargo__package_root() {
  @unwrap __testing__frameworks__cargo__package_root__manifest "$1"
  if ! @defined "$(toml__get "$PROJ/$__testing__frameworks__cargo__package_root__manifest" package name)"; then
    printf ''
    return 0
  fi
  if [ "$__testing__frameworks__cargo__package_root__manifest" = "Cargo.toml" ]; then
    printf '.'
    return 0
  fi
  printf '%s' "${__testing__frameworks__cargo__package_root__manifest%/Cargo.toml}"
}

:<<'FUN'
The absolute path to the cargo workspace manifest named by the suite config's
`manifest` field (joined under $PROJ), or empty when the field is absent -- in
which case cargo runs against whatever workspace the working directory roots. A
top-level helper shared by the run roles.

args:
  $1  The effective suite config
FUN
__testing__frameworks__cargo__manifest_path() {
  @get __testing__frameworks__cargo__manifest_path__rel "$1" '.manifest' ''
  if @defined "$__testing__frameworks__cargo__manifest_path__rel"; then
    printf '%s' "$PROJ/$__testing__frameworks__cargo__manifest_path__rel"
  fi
}

:<<'PUB_FUN'
The absolute root of the workspace the suite runs in: the directory of the
manifest the suite config names, or $PROJ when it names none. Shared by every
cargo-based runner that leaves a report under the workspace's target directory.

args:
  $1  The effective suite config
PUB_FUN
testing__frameworks__cargo__workspace_root() {
  __testing__frameworks__cargo__workspace_root__manifest="$(__testing__frameworks__cargo__manifest_path "$1")"
  if @defined "$__testing__frameworks__cargo__workspace_root__manifest"; then
    dirname "$__testing__frameworks__cargo__workspace_root__manifest"
    return 0
  fi
  printf '%s' "$PROJ"
}

:<<'FUN'
The given package names narrowed to the members of the workspace rooted at the
given manifest. `cargo -p NAME` resolves only against that workspace's members,
yet a crate nested inside an area can declare its own `[workspace]` and so own
sources without joining it; passing such a name through would abort the run
with "did not match any packages". With no manifest cargo resolves against
whatever workspace the working directory roots, and with no names there is
nothing to narrow, so both cases skip the metadata lookup and pass the names
straight back. A top-level helper shared by the run_selected role.

args:
  $1  Manifest path, or "" for the working directory's workspace
  $2  Package names (struct array)
FUN
__testing__frameworks__cargo__workspace_members_only() {
  @len __testing__frameworks__cargo__workspace_members_only__count "$2"
  if [ -z "$1" ] || [ "$__testing__frameworks__cargo__workspace_members_only__count" -eq 0 ]; then
    printf '%s' "$2"
    return 0
  fi

  __testing__frameworks__cargo__workspace_members_only__cargo__members_only__members="$(cargo__workspace_member_names "$1")" || return 1
  @intersect __testing__frameworks__cargo__workspace_members_only__out "$2" "$__testing__frameworks__cargo__workspace_members_only__cargo__members_only__members"
  println "$__testing__frameworks__cargo__workspace_members_only__out"
}

:<<'PUB_FUN'
The packages a run selects for the given files: the sorted, unique names of the
packages owning them, narrowed to the members of the suite's workspace. Empty
when no file maps to a member, which every runner reads as "run the whole
suite". Shared by every cargo-based runner (cargo, tarpaulin, llvm_cov) so the
selection rule is written once and the runners cannot disagree on it.

args:
  $1  The effective suite config
  $@  Test file paths, relative to $PROJ
PUB_FUN
testing__frameworks__cargo__selected_packages() {
  __testing__frameworks__cargo__selected_packages__manifest="$(__testing__frameworks__cargo__manifest_path "$1")"
  shift
  __testing__frameworks__cargo__selected_packages__names="$(__testing__frameworks__cargo__packages_for_files "$@")"
  __testing__frameworks__cargo__workspace_members_only \
    "$__testing__frameworks__cargo__selected_packages__manifest" \
    "$__testing__frameworks__cargo__selected_packages__names"
}

:<<'PUB_FUN'
Prints the cargo arguments naming the suite's workspace manifest, one per line
(--manifest-path, then the absolute path), or nothing when the suite names no
manifest. Shared by every cargo-based runner.

args:
  $1  The effective suite config
PUB_FUN
testing__frameworks__cargo__manifest_args() {
  __testing__frameworks__cargo__manifest_args__path="$(__testing__frameworks__cargo__manifest_path "$1")"
  if @defined "$__testing__frameworks__cargo__manifest_args__path"; then
    printf '%s\n%s\n' --manifest-path "$__testing__frameworks__cargo__manifest_args__path"
  fi
}

:<<'PUB_FUN'
Prints the cargo arguments selecting the given packages, one per line (-p, then
a name, per package), or nothing for an empty selection. Shared by every
cargo-based runner.

  testing__frameworks__cargo__package_args '["alpha","zeta"]'  ->  -p
                                                alpha
                                                -p
                                                zeta

args:
  $1  Package names (struct array)
PUB_FUN
testing__frameworks__cargo__package_args() {
  @len __testing__frameworks__cargo__package_args__count "$1"
  __testing__frameworks__cargo__package_args__i=0
  while [ "$__testing__frameworks__cargo__package_args__i" -lt "$__testing__frameworks__cargo__package_args__count" ]; do
    @get __testing__frameworks__cargo__package_args__get_4 "$1" ".[$__testing__frameworks__cargo__package_args__i]"
    printf '%s\n%s\n' -p "$__testing__frameworks__cargo__package_args__get_4"
    __testing__frameworks__cargo__package_args__i=$((__testing__frameworks__cargo__package_args__i + 1))
  done
}

:<<'PUB_FUN'
The extra arguments a suite config hands to cargo for its run (`cargo_args`), as
a struct array; [] when the suite sets none. Shared by the instrumented runners.

args:
  $1  The effective suite config
PUB_FUN
testing__frameworks__cargo__extra_args() {
  @arr __testing__frameworks__cargo__extra_args__arr_5
  @get __testing__frameworks__cargo__extra_args__out "$1" '.cargo_args' "$__testing__frameworks__cargo__extra_args__arr_5"
  println "$__testing__frameworks__cargo__extra_args__out"
}

:<<'PUB_FUN'
The ignore patterns a suite config names (`ignore`, a string or a list), as a
struct array with empty patterns dropped: an empty pattern would reach a tool as
an argument of its own, and for a regex engine a stray "" widens the pattern to
everything. Shared by the instrumented runners.

  testing__frameworks__cargo__ignore_patterns '{"ignore": ["src/bin/", ""]}'  ->  ["src/bin/"]

args:
  $1  The effective suite config
PUB_FUN
testing__frameworks__cargo__ignore_patterns() {
  @filter __testing__frameworks__cargo__ignore_patterns__out "$(testing__suite_patterns "$1" '.ignore')" silt__text_is_not . ''
  println "$__testing__frameworks__cargo__ignore_patterns__out"
}

:<<'PUB_FUN'
Prints a struct array's elements one per line, so a caller can load them into
positional arguments with mapfile. Shared by every cargo-based runner.

  testing__frameworks__cargo__lines '["--locked","--no-default-features"]'  ->  --locked
                                                            --no-default-features

args:
  $1  A struct array of strings
PUB_FUN
testing__frameworks__cargo__lines() {
  @len __testing__frameworks__cargo__lines__count "$1"
  __testing__frameworks__cargo__lines__i=0
  while [ "$__testing__frameworks__cargo__lines__i" -lt "$__testing__frameworks__cargo__lines__count" ]; do
    @get __testing__frameworks__cargo__lines__get_6 "$1" ".[$__testing__frameworks__cargo__lines__i]"
    println "$__testing__frameworks__cargo__lines__get_6"
    __testing__frameworks__cargo__lines__i=$((__testing__frameworks__cargo__lines__i + 1))
  done
}

:<<'DOC'
The cargo framework runner; inner @-roles re-home to cargo_<role> on load.
DOC
@runner.cargo() {
  :<<'FUN'
Runs cargo tests for the packages owning the selected files (each a
$PROJ-relative path), in the workspace named by the suite config. Only that
workspace's own members are selectable; with no member left to select, runs the
whole suite. Passes the cargo exit code through.
FUN
  @run_selected() {
    __cargo_run_selected__cfg="$1"
    shift
    __cargo_run_selected__packages="$(testing__frameworks__cargo__selected_packages "$__cargo_run_selected__cfg" "$@")" || return 1

    mapfile -t __cargo_run_selected__args < <(
      testing__frameworks__cargo__manifest_args "$__cargo_run_selected__cfg"
      testing__frameworks__cargo__package_args "$__cargo_run_selected__packages"
    )

    cargo test "${__cargo_run_selected__args[@]}"
  }

  :<<'FUN'
Runs the whole workspace's tests in the workspace named by the suite config,
passing the cargo exit code through.
FUN
  @run_all() {
    mapfile -t __cargo_run_all__args < <(testing__frameworks__cargo__manifest_args "$1")
    cargo test --workspace "${__cargo_run_all__args[@]}"
  }

  :<<'FUN'
The manifest-facing JSON Schema fragment for a cargo suite.
FUN
  @suite_schema() {
    cat "$SHELLOPS_DIR/lib/testing/frameworks/cargo/suite.schema.json"
  }

  :<<'FUN'
The discovery strategy cargo opts into beyond "default": the common
"native", implemented as a package walk over the framework's own metadata
("embedded" is reserved, not yet implemented -- see OPS-270).
FUN
  @strategies() {
    @arr __at_out native
    println "$__at_out"
  }

  :<<'FUN'
cargo's default suite config; gathers the area's Rust sources ("*.rs") for the
package walk. `glob` is an internal default, not a manifest override.
FUN
  @suite_defaults() {
    @arr __at7 native
    @obj __at_out \
      '.runner' "cargo" \
      '.glob' "*.rs" \
      '.discovery' "$__at7"
    println "$__at_out"
  }

  :<<'FUN'
The "native" discovery strategy for every area at once -- cargo's test set
is its package structure, so the framework's own metadata (the tracked
Cargo.tomls) answers without executing cargo. Finds the Rust sources
under each area's paths, keeps the ones a cargo package owns, and returns
them keyed by area. Any other strategy returns {}.

In a repo where engine/cache is a package:

  cargo_discover_all native '{"engine": ["engine"]}' '["*.rs"]' '[]'
  -> {"engine": ["engine/cache/src/state.rs"]}

args:
  $1  Strategy
  $2  Paths by area ({<area>: [<path>, ...]})
  $3  Globs (struct array)
  $4  Excludes (struct array)
FUN
  @discover_all() {
    if [ "$1" != "native" ]; then
      @obj __at_out
      println "$__at_out"
      return 0
    fi

    __cargo_discover_all__candidates="$(testing__glob_files_by_area "$2" "$3" "$4")"
    __cargo_discover_all__roots="$(testing__frameworks__cargo__package_roots)"

    @run_awk __at_out "$SHELLOPS_DIR/lib/testing/frameworks/cargo/owned_files.awk" \
      "$__cargo_discover_all__candidates" \
      --with "$__cargo_discover_all__roots" \
      --load "$SHELLOPS_DIR/lib/testing/testing.awk" || return 1
    println "$__at_out"
  }

  :<<'FUN'
The "native" discovery strategy for a single area. Wraps the area's paths as a
one-entry map, resolves it through cargo_discover_all, and returns that one
answer, so both entry points follow the same rule. Any other strategy
returns [].

args:
  $1  Strategy
  $2  Paths (struct array)
  $3  Globs (struct array)
  $4  Excludes (struct array)
FUN
  @discover() {
    @obj __at8 '.area' "$2"
    __cargo_discover__derived="$(cargo_discover_all \
      "$1" \
      "$__at8" \
      "$3" \
      "$4"
    )"
    @arr __at9
    @get __at10 "$__cargo_discover__derived" '.area' "$__at9"
    @compact __at_out "$__at10"
    println "$__at_out"
  }
}

# Desugar @runner.cargo into the flat cargo_<role> functions, then register under
# "cargo". Guarded so a re-import sources the interpreter, desugars, and registers
# at most once.
command -v interpreter__load_runner >/dev/null 2>&1 \
  || import "$SHELLOPS_DIR/interpreter/api.sh"
command -v cargo_run_selected >/dev/null 2>&1 \
  || interpreter__load_runner cargo @runner.cargo
@is_true "$(testing__adapter_registered cargo)" || testing__register_adapter cargo
