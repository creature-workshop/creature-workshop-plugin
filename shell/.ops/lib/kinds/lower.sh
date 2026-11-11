#!/bin/sh

: <<'MODULE'
Lowering a structural contract to the plain functions a load reads (api.sh
says how a plugin loads). A plugin file declares @<kind>.<name>() whose inner
@<role>() functions are its roles. Lowering drops the outer, writes each role
as <name>_<role>() and each call to a role as a call to that name, and
carries everything else in the file through as it is. That is the shape the
engine emits once it compiles the contracts (ADR 000009); until then it is
written here, so a plugin spells its roles without the prefix and the
lowered copy is what loads, derived under the owner's .ops/__compiled__/
(ADR 000037, ADR 000047).

  kinds__lower type int "is from default" "is from" lib/structs/types/int.type.op.sh
    ->  int_is() { ... }
        int_from() { ...; }
        int_default() { ...; }
MODULE

: <<'PUB_FUN'
Prints the plain-function form of the plugin <name> of kind <kind> declared
in <file>. Fails, with a diagnostic on stderr naming kind, plugin and role,
when the file declares another plugin, defines a role the kind does not
declare, or leaves a required role out.

args:
  $1  The kind
  $2  The plugin name
  $3  The space-separated roles the kind declares
  $4  The space-separated roles the kind requires
  $5  The plugin file, named in the lowered file's header as given
PUB_FUN
kinds__lower() {
  awk \
    -v kind="$1" \
    -v name="$2" \
    -v roles="$3" \
    -v required="$4" \
    -v source="$5" \
    -f "$SHELL_SCAN_DIR/shell/scan/scan.awk" \
    -f "$SHELLOPS_DIR/lib/kinds/lower.awk" \
    "$5"
}
