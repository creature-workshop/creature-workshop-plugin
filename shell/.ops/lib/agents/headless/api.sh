#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/agents/headless/context.sh" \
  "$SHELLOPS_DIR/lib/agents/headless/options.sh" \
  "$SHELLOPS_DIR/lib/agents/headless/state.sh" \
  "$SHELLOPS_DIR/lib/agents/headless/argv.sh" \
  "$SHELLOPS_DIR/lib/agents/headless/process.sh" \
  "$SHELLOPS_DIR/lib/agents/headless/record.sh" \
  "$SHELLOPS_DIR/lib/agents/headless/roles.sh"

:<<'DOC'
The headless base an agent adaptor stands on when its provider is a command
line rather than a service: the CLI runs in the process that asked for it,
over the checkout that process is standing in, and its state is files on
disk.

An agent is one conversation the CLI holds, a run is one headless invocation
over that conversation, and a followup is a further run on it. A run's state
lives under <state>/<agent>/<run>/ as the prompt it was given, the CLI's
output and errors, the pid of the process and, once it ends, its exit code. A
cancel kills the process group and leaves a marker, so the record says
CANCELLED and never ERROR for a run the caller stopped.

Two things differ between one CLI and the next: the adaptor's own id, which
names its options block and the directory its state goes under, and the
environment variable that carries its key into the child process. An adaptor
names both once, in a context it builds at import, and passes that context to
everything here:

  __agents__claude_cli__CONTEXT="$(agents__headless__context claude-cli ANTHROPIC_API_KEY)"
  agents__headless__get_run "$__agents__claude_cli__CONTEXT" "$options" "$agent" "$run"

What is left for the adaptor is what only it can say: the variable it names,
the command line its CLI takes, and the models it accepts. Six of the ten
roles lib/agents/base.sh lists -- the reads and the ends of a run -- this
base answers whole, in roles.sh.

The options block an adaptor reads is shared the same way: the executable,
the workspace and the state directory mean the same for any CLI, so
agents__headless__new_options holds their defaults and options.schema.json defines
them for every adaptor's block; the adaptor adds what only its CLI takes.
DOC
