#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'FRAGMENT'
The block of the run options a headless adaptor reads, and the defaults a run
starts from before a caller has named anything. Three of those defaults are the
same whichever CLI the adaptor drives, so the base names them here and an
adaptor adds its own on top -- the same division
lib/agents/headless/options.schema.json makes for the schema each adaptor's
block is checked against.
FRAGMENT

:<<'PUB_FUN'
Prints the block a headless run starts from: the executable $1 the adaptor
runs, an empty workspace and an empty state directory, which agents__headless__workspace
and agents__headless__state_dir read as "work the directory out", and whatever further
defaults $2... the adaptor adds for its own CLI. A caller overrides a field
before handing the options to the facade.

  agents__headless__new_options claude '.bare' true
  ->  {"command":"claude","workspace":"","state_dir":"","bare":true}

args:
  $1     The CLI executable the adaptor runs unless the caller names another
  $2...  The adaptor's own defaults, as @obj takes them: a path, then a value
PUB_FUN
agents__headless__new_options() {
  __agents__headless__new_options__command="$1"
  shift
  @obj __agents__headless__new_options__out \
    '.command'   "$__agents__headless__new_options__command" \
    '.workspace' '' \
    '.state_dir' '' \
    "$@"
  println "$__agents__headless__new_options__out"
}
