#!/bin/sh

:<<'MODULE'
The roles of the type kind: what a type plugin may define and what it must.
Declared apart from the kind, in plain shell, so the compile can hold a
plugin to them before the structs library loads (ADR 000047).
MODULE

# CONST: The space-separated roles the type kind declares.
__structs__roles__DECLARED="is from default values new"

# CONST: The space-separated roles every type must define.
__structs__roles__REQUIRED="is from"

:<<'PUB_FUN'
Writes the space-separated roles the type kind declares, what ops compile
holds a plugin to, into the variable named first. Assigns in plain shell,
since the compile calls it before the structs library loads.

  @type_roles x  ->  x="is from default values new"
PUB_FUN
@type_roles() {
  eval "$1=\$__structs__roles__DECLARED"
}

:<<'PUB_FUN'
Writes the space-separated roles every type must define into the variable
named first.
PUB_FUN
@type_required() {
  eval "$1=\$__structs__roles__REQUIRED"
}
