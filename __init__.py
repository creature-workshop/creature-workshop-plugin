"""The entry point of the plugin's Python side: Creature Workshop, a project's
shellops declaration, toolchain, tests and lint in Hermes.

Hermes imports this file as the plugin and calls register(ctx) once at startup. It registers one tool per lifecycle
verb and a system prompt section that tells the agent, when the session's
directory is a shellops project, what the project declares and which tools are
missing, and the hook in workshop/agent/guard.py, which blocks a terminal command
naming a declared tool that is not installed. The Desktop pane in desktop/ reads the same facts through the backend
in dashboard/plugin_api.py.
"""

from .workshop.agent import guard, session, tools
from .workshop.consent import is_approved
from .workshop.project.declaration import find_project, summary_line


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

  summary = summary_line(root)
  if not is_approved(root):
    return (
      f"{summary} This project has not been approved for execution yet. "
      f"Before running any workshop_* tool, call workshop_install with approve: true "
      f"and path: \"{root}\" to record the user's consent."
    )

  return (
    f"{summary} The workshop_* tools run its shell/ops: workshop_project for the "
    "declaration and the toolchain, workshop_install to check or install declared tools, "
    "workshop_test for the test plan of changed paths, workshop_lint for the house-style lint."
  )
