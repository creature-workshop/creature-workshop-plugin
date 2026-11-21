#!/bin/sh

: <<'MODULE'
A repository's boot, .ops/boot: the hand-off to shellops, the same in
every repository (ADR.21@global, ADR 000047). init writes it from
lib/self/boot.template.sh and rewrites it only when what it would write
differs from what stands, so the file changes when its shape does and
never for a run that changes nothing.

A boot written before the seeds moved into the lock (ADR 000049) carries
the owner's doc seed and line seed, and this module reads them from it,
so init can copy them into the lock once. It speaks in paths and plain
shell alone, so a seed can be read before the structs library loads.

  self__boot__doc_seed "$PROJ"   ->  335499942
  self__boot__line_seed "$PROJ"  ->  2931084477
MODULE

: <<'CONST'
Where an owner keeps its boot, under the folder shellops manages (ADR
000011): the one file there that is tracked (ADR 000047).
CONST
__self__boot__FILE='.ops/boot'

# CONST: The template a boot is rendered from, the vendored path filled in.
__self__boot__TEMPLATE="$SHELLOPS_DIR/lib/self/boot.template.sh"

# CONST: The constant of a boot written before the seeds moved into the lock that carries the doc seed.
__self__boot__DOC_SEED='SHELLOPS_DOC_SEED'

# CONST: The constant of such a boot that carries the line seed.
__self__boot__LINE_SEED='SHELLOPS_LINE_SEED'

: <<'PUB_FUN'
Sets __self__boot__path__file to the boot of the owner <dir>: <dir>/.ops/boot.
Sets a variable rather than printing, so asking forks nothing.

  self__boot__path "$PROJ"  ->  $PROJ/.ops/boot

Usage: self__boot__path <owner>
PUB_FUN
self__boot__path() {
  __self__boot__path__file="$1/$__self__boot__FILE"
}

: <<'PUB_FUN'
Prints the doc seed the owner <dir>'s boot carries, or nothing when the
owner has no boot or its boot carries none, as a boot written since the
seeds moved into the lock carries none.

Usage: self__boot__doc_seed <owner>
PUB_FUN
self__boot__doc_seed() {
  __self__boot__constant "$1" "$__self__boot__DOC_SEED"
}

: <<'PUB_FUN'
Prints the line seed the owner <dir>'s boot carries, or nothing when the
owner has no boot or its boot carries none.

Usage: self__boot__line_seed <owner>
PUB_FUN
self__boot__line_seed() {
  __self__boot__constant "$1" "$__self__boot__LINE_SEED"
}

: <<'FUN'
Prints the value the owner <dir>'s boot assigns the constant <name>, or
nothing when the owner has no boot or its boot assigns it nothing. Reads
with the shell's builtins alone.

Usage: __self__boot__constant <owner> <name>
FUN
__self__boot__constant() {
  self__boot__path "$1"
  [ -f "$__self__boot__path__file" ] || return 0
  while IFS= read -r __self__boot__constant__line; do
    case "$__self__boot__constant__line" in
      "$2="*)
        printf '%s\n' "${__self__boot__constant__line#"$2="}"
        return 0
        ;;
    esac
  done < "$__self__boot__path__file"
}

: <<'PUB_FUN'
Prints the boot of a repository that vendors shellops at <shellops>, a path
relative to the repository root.

  self__boot__render shell/.ops
    ->  #!/bin/sh
        ...
        exec "$here/shell/.ops/init" "$@"

Usage: self__boot__render <shellops>
PUB_FUN
self__boot__render() {
  sed -e "s|@@SHELLOPS@@|$1|g" "$__self__boot__TEMPLATE"
}

: <<'PUB_FUN'
Writes the owner <dir>'s boot, handing off to shellops at <shellops>,
unless the boot standing there already reads so, in which case nothing is
written and the file keeps its time. The boot is written whole, beside the
standing one, and moved into place, so no reader meets a half-written
boot. Says which it did.

Usage: self__boot__write <owner> <shellops>
PUB_FUN
self__boot__write() {
  self__boot__path "$1"
  __self__boot__write__fresh="$__self__boot__path__file.$$"
  mkdir -p "$(dirname "$__self__boot__path__file")"
  self__boot__render "$2" > "$__self__boot__write__fresh"
  if [ -f "$__self__boot__path__file" ] && cmp -s "$__self__boot__write__fresh" "$__self__boot__path__file"; then
    rm -f "$__self__boot__write__fresh"
    log "$__self__boot__FILE is current"
    return 0
  fi
  chmod +x "$__self__boot__write__fresh"
  mv "$__self__boot__write__fresh" "$__self__boot__path__file"
  log "wrote $__self__boot__FILE"
}
