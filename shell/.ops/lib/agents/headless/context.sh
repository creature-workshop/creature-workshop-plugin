#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

:<<'FRAGMENT'
What one headless adaptor tells the base about itself, so the base can do
the rest for any of them.
FRAGMENT

:<<'PUB_FUN'
Prints the context every other headless call takes: the adaptor's id $1, the
environment variable $2 that carries its key into the CLI, and the options
schema beside the adaptor's plugin, which the id names.

  agents__headless__context claude-cli ANTHROPIC_API_KEY
  ->  {"id":"claude-cli","token_env":"ANTHROPIC_API_KEY","schema":"<lib>/agents/claude-cli/options.schema.json"}
PUB_FUN
agents__headless__context() {
  @obj __agents__headless__context__out \
    '.id'        "$1" \
    '.token_env' "$2" \
    '.schema'    "$SHELLOPS_DIR/lib/agents/$1/options.schema.json"
  println "$__agents__headless__context__out"
}
