"""Guarding the terminal: a command that names a declared tool the project has
not installed is blocked before it runs, with the install as the hint.

Hermes calls before_tool_call before every tool runs. For the terminal tool,
in a session whose directory is a shellops project, the hook reads the
programs the command runs and checks them against the project's declaration.
A program the declaration names but `ops install --check` reports missing
blocks the call: the message names the tool, its declared version and channel,
and workshop_install as the fix, so the agent installs it and retries instead
of failing on a command that was never going to work. Everything else passes:
other tools, undeclared programs, a directory outside any project, and a check
that fails or runs out of time, because the hook is a hint and not a gate.

The check's result is cached per project for the pane_refresh_seconds setting
and forgotten after an install, since Hermes gives a hook thirty seconds and
blocks the tool when it runs out.
"""

import re
import shlex
import time

from . import check_table, ops, session, settings
from .project import declared_tools, find_project

TERMINAL_TOOL = "terminal"
CHECK_TIMEOUT_SECONDS = 20
WRAPPERS = frozenset(["sudo", "env", "nice", "ionice", "time", "nohup", "command", "exec"])
SEGMENTS = re.compile(r"\|\||&&|[|;&\n]")
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
CACHE = {}


def before_tool_call(tool_name, args, task_id="", **kwargs):
  """Hermes's pre_tool_call hook: the block directive for a terminal command that
  names a declared tool which is not installed, else None to let the call run."""

  if tool_name != TERMINAL_TOOL or not isinstance(args, dict):
    return None

  root = find_project(args.get("workdir") or session.directory())
  if root is None:
    return None

  blocked = blocked_tools(root, programs_of(str(args.get("command") or "")))
  if not blocked:
    return None

  return {"action": "block", "message": block_message(root, blocked)}


def blocked_tools(root, programs):
  """[(tool, version, channel)] for the programs the declaration names and the
  check reports missing, each once, in the command's order."""

  declared = {tool: (version, channel) for channel, tool, version in declared_tools(root)}
  named = [program for program in programs if program in declared]
  if not named:
    return []

  missing = missing_tools(root)
  return [(tool, *declared[tool]) for tool in dict.fromkeys(named) if tool in missing]


def missing_tools(root):
  """The declared tools the check reports as not installed: from the cache while it
  is fresh, else from a run of `ops install --check`. Empty when the check prints
  no table, which is how a failed or timed-out check blocks nothing."""

  key = str(root)
  expires, cached = CACHE.get(key, (0, frozenset()))
  if time.monotonic() < expires:
    return cached

  outcome = ops.run(root, ["install", "--check"], CHECK_TIMEOUT_SECONDS)
  found = frozenset(row["tool"] for row in check_table.rows(outcome) if not row["installed"])
  CACHE[key] = (time.monotonic() + settings.value("pane_refresh_seconds"), found)
  return found


def forget(root):
  """Drops the cached check for the project, after an install changed what is there."""

  CACHE.pop(str(root), None)


def programs_of(command):
  """The programs a shell command runs, one per pipeline segment, without the
  wrappers, variable assignments and options in front of each:

    programs_of("FOO=1 sudo rsync -a src dst | tee log")  ->  ["rsync", "tee"]
  """

  programs = []
  for segment in SEGMENTS.split(command):
    program = program_of(segment)
    if program:
      programs.append(program)

  return programs


def program_of(segment):
  """The program one segment of a command runs, by its base name, or empty when it runs none."""

  for word in words_of(segment):
    if ASSIGNMENT.match(word) or word.startswith("-") or word in WRAPPERS:
      continue

    return word.rsplit("/", 1)[-1]

  return ""


def words_of(segment):
  """The words of a segment, split as a shell would, or on spaces when the quoting is broken."""

  try:
    return shlex.split(segment)
  except ValueError:
    return segment.split()


def block_message(root, blocked):
  """What the agent reads instead of the command's output: each missing tool, with
  its declared version and channel, and the install as the next step."""

  lines = [
    f"{tool} is declared in .ops/config/tools.yaml at {version} on the {channel} channel but is not installed, so this command would fail."
    for tool, version, channel in blocked
  ]

  names = ", ".join(tool for tool, _, _ in blocked)
  lines.append(
    f"Install it first with workshop_install, tools: [{names}], check: false, which runs shell/ops install {names} in {root}; then run the command again."
  )

  return "\n".join(lines)
