"""The entry point of the plugin's Python side: Creature Workshop, a project's
shellops declaration, toolchain, tests and lint in Hermes.

Hermes imports this file as the plugin and calls register(ctx) once at startup. It registers one tool per lifecycle
verb and a system prompt section that tells the agent, when the session's
directory is a shellops project, what the project declares and which tools are
missing, and the hook in workshop/guard.py, which blocks a terminal command
naming a declared tool that is not installed. The Desktop pane in desktop/ reads the same facts through the backend
in dashboard/plugin_api.py.
"""

from .workshop import guard, session, tools
from .workshop.project import find_project, summary_line


def register(ctx):
  """Registers the plugin with Hermes: its tools, its section of the system prompt, and the hook that checks a tool call before it runs."""

  for schema, handler in tools.registry():
    ctx.register_tool(name=schema["name"], toolset="workshop", schema=schema, handler=handler)

  ctx.register_system_prompt_section("creature-workshop", prompt_section, max_chars=800)
  ctx.register_hook("pre_tool_call", guard.before_tool_call)


def prompt_section(session_info):
  """One short paragraph for the system prompt, or nothing outside a shellops project."""

  root = find_project(session.directory())
  if root is None:
    return ""

  return (
    f"{summary_line(root)} The workshop_* tools run its shell/ops: workshop_project for the "
    "declaration and the toolchain, workshop_install to check or install declared tools, "
    "workshop_test for the test plan of changed paths, workshop_lint for the house-style lint."
  )
