#!/bin/sh

import "$SHELLOPS_DIR/lib/agents/headless/api.sh"

:<<'FRAGMENT'
The claude-cli block of the run options: the context every headless call takes
it under, and the defaults a run starts from. Every other file of this adaptor
reads the block through these two rather than reaching into the options by
path, so what a key is called and what it does when nobody names it are written
down once.
FRAGMENT

__agents__claude_cli__CONTEXT="$(agents__headless__context claude-cli ANTHROPIC_API_KEY)"

:<<'FUN'
Prints the claude-cli block a run starts from: the three every headless adaptor
understands, then how the CLI may act with nobody there to ask, which MCP
servers it may reach, which tools it may use, how hard it thinks and what it
may spend. A caller overrides a field before handing the options to the facade.

An empty string is "the CLI's own": the command line leaves that flag off and
lets the Claude Code CLI decide, which is why effort and max_budget_usd start
empty rather than at a number this adaptor made up.

  __agents__claude_cli__new_options
  ->  {"command":"claude","workspace":"","state_dir":"","mcp_config":"",
       "permission_mode":"bypassPermissions","bare":true,"allowed_tools":[],
       "effort":"","max_budget_usd":""}
FUN
__agents__claude_cli__new_options() {
  @arr __agents__claude_cli__new_options__arr_1
  agents__headless__new_options claude \
    '.mcp_config'      '' \
    '.permission_mode' bypassPermissions \
    '.bare'            true \
    '.allowed_tools'   "$__agents__claude_cli__new_options__arr_1" \
    '.effort'          '' \
    '.max_budget_usd'  ''
}
