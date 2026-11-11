#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELLOPS_DIR/lib/opx/seed.sh"

: <<'FRAGMENT'
OPX as a data format: a JSON value stored as an OPX document and read back.

OPX writes a tree one node per line, "<id> <depth>.<role>" for a node with
children and "<id> <depth>.<role>:<type>.<value>" for a leaf, so a program
reads it a line at a time with no parser: grep finds a role, and an awk rule
reads a field. A role is a bare word, or any other text written quoted, so
an object's key is its member's role whatever the key holds. lines.awk
beside this file is what an awk program loads to read a line, emit.awk what
it loads to write one, and mapping.awk says how a JSON value is laid out.
YAML is read into the same value and written from it, by the files under
yaml/. Every translator runs on awk alone, whichever
backend structs is on.
FRAGMENT

__opx__DIR="$SHELLOPS_DIR/lib/opx"

: <<'PUB_FUN'
Prints the JSON document on stdin as an OPX document, every node under an id
drawn at random from PROJ's seed, the one `ops compile` keeps in the bundle,
and the document's unit. The same document under the same unit prints the
same bytes on every compile and every machine, and two units draw different
ids. Where PROJ carries no seed yet the ids are drawn afresh. Fails when
stdin is not one JSON value, or when an object in it holds a key twice.

    opx__from_json value trace/map < map.json  ->  xK_mQ 0.value
                                                   Lp3qR 1.commit:null.null

args:
  $1  The root node's role (optional, "value" when not given or empty)
  $2  The unit: the document's name within the compilation (optional)
  $3  The seed, in place of PROJ's (optional)
PUB_FUN
opx__from_json() {
  @awk __opx__from_json__out "$__opx__DIR/emit.awk" \
    -f "$__opx__DIR/mapping.awk" \
    -f "$__opx__DIR/write_tree.awk" \
    -f "$__opx__DIR/from_json.awk" \
    -v root="${1:-}" \
    -v unit="${2:-}" \
    -v seed="${3:-$(__opx__seed)}" || return 1
  println "$__opx__from_json__out"
}

: <<'PUB_FUN'
Prints the OPX document on stdin as one compact line of JSON, the inverse of
opx__from_json. Fails, naming the line, on one that is no OPX node, that is
out of place in the tree or under a leaf, that repeats a key of its object,
or that mixes an array's items with an object's members.

    opx__to_json < value.opx  ->  {"a":[1,"x"]}
PUB_FUN
opx__to_json() {
  @awk __opx__to_json__out "$__opx__DIR/lines.awk" \
    -f "$__opx__DIR/mapping.awk" \
    -f "$__opx__DIR/read_tree.awk" \
    -f "$__opx__DIR/to_json.awk" || return 1
  println "$__opx__to_json__out"
}

: <<'PUB_FUN'
Prints the YAML document on stdin as an OPX document, laid out as the JSON of
the same value would be. Reads block mappings and sequences, plain and quoted
scalars, literal and folded blocks, one-line flow collections and comments;
fails, naming the line, on what it does not read: anchors and aliases, tags,
merge keys, complex keys, directives, a second document, and a scalar or a
flow collection that runs over lines. Ids are drawn as opx__from_json draws
them: from PROJ's seed and the document's unit.

    opx__from_yaml < pipeline.yml  ->  xK_mQ 0.value
                                       Lp3qR 1.stages
                                       d1E02 2.item:string."test"

args:
  $1  The root node's role (optional, "value" when not given or empty)
  $2  The unit: the document's name within the compilation (optional)
  $3  The seed, in place of PROJ's (optional)
PUB_FUN
opx__from_yaml() {
  @awk __opx__from_yaml__out "$__opx__DIR/yaml/lines.awk" \
    -f "$__opx__DIR/yaml/scalars.awk" \
    -f "$__opx__DIR/yaml/flow.awk" \
    -f "$__opx__DIR/yaml/blocks.awk" \
    -f "$__opx__DIR/yaml/parse.awk" \
    -f "$__opx__DIR/emit.awk" \
    -f "$__opx__DIR/mapping.awk" \
    -f "$__opx__DIR/write_tree.awk" \
    -f "$__opx__DIR/from_yaml.awk" \
    -v root="${1:-}" \
    -v unit="${2:-}" \
    -v seed="${3:-$(__opx__seed)}" || return 1
  println "$__opx__from_yaml__out"
}

: <<'PUB_FUN'
Prints the OPX document on stdin as a YAML document in block style, a string
quoted only where a plain one would read back as something else. The value
survives a round trip through opx__from_yaml; comments and the author's
choice of style do not.

    opx__to_yaml < value.opx  ->  stages:
                                    - test
PUB_FUN
opx__to_yaml() {
  @awk __opx__to_yaml__out "$__opx__DIR/lines.awk" \
    -f "$__opx__DIR/mapping.awk" \
    -f "$__opx__DIR/read_tree.awk" \
    -f "$__opx__DIR/yaml/scalars.awk" \
    -f "$__opx__DIR/yaml/serialize.awk" \
    -f "$__opx__DIR/to_yaml.awk" || return 1
  println "$__opx__to_yaml__out"
}

: <<'FUN'
Prints the seed a document's ids are drawn from when the caller names none:
PROJ's, or a fresh one where PROJ carries none.
FUN
__opx__seed() {
  __opx__seed__owned="$(opx__seed__of_owner)"
  if @defined "$__opx__seed__owned"; then
    println "$__opx__seed__owned"
    return
  fi
  opx__seed__mint
}
