"""The entry point of the plugin's Python side: Creature Workshop, a project's
shellops declaration, toolchain, tests and lint in Hermes.

Hermes imports this file as the plugin and calls register(ctx) once at
startup. It registers the tools in workshop/agent/tools.py, one per lifecycle
verb; a system prompt section
that says what the tools are for; and four hooks. One tells the agent each
turn which project its session is on, two keep that selection with a chat
when Hermes compresses it or starts a subagent, and the one in
workshop/agent/guard.py blocks a terminal command naming a declared tool that
is not installed. It also registers the auxiliary task the Dependencies
tab's Explain button asks a model through, so that model is a setting of
its own, which starts on a free one.
The Desktop pane in desktop/ reads the same selection and
the same facts through the backend in dashboard/plugin_api.py.
"""

from .workshop.agent import context, guard, tools
from .workshop.project import explain


def register(ctx):
  """Registers the plugin with Hermes: its tools, its section of the system prompt, its hooks, and its auxiliary task."""

  for schema, handler in tools.registry():
    ctx.register_tool(name=schema["name"], toolset="workshop", schema=schema, handler=handler)

  ctx.register_system_prompt_section("creature-workshop", context.prompt_section, max_chars=800)
  ctx.register_hook("pre_tool_call", guard.before_tool_call)
  ctx.register_hook("pre_llm_call", context.before_turn)
  ctx.register_hook("post_compaction", context.after_compaction)
  ctx.register_hook("subagent_start", context.on_subagent_start)
  explain.register_task(ctx)
