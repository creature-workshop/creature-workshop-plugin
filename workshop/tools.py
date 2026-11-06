"""The tools the agent calls, one per lifecycle verb, each a thin wrapper of shell/ops.

Every handler takes the tool's arguments as a mapping and returns a JSON string,
on success and on failure alike, and never raises: Hermes shows the agent
whatever comes back. A handler finds the project from the `path` argument, or
from the session's directory when there is none.
"""
import json
import os

from . import ops, settings
from .schemas import INSTALL_SCHEMA, LINT_SCHEMA, PROJECT_SCHEMA, TEST_SCHEMA
from .project import declaration, declared_tools, find_project, release, summary_line


def session_directory():
  """The directory the session works in: Hermes's configured one, else this process's."""
  try:
    from agent.runtime_cwd import resolve_agent_cwd

    return str(resolve_agent_cwd())
  except Exception:
    return os.getcwd()


def project_for(args):
  """(root, error) for the project the arguments point at; one of the two is None."""
  start = args.get("path") or session_directory()
  root = find_project(start)
  if root is None:
    return None, (f"{start} is not inside a shellops project: no shell/ops and .ops/config above it. "
           "A project gets them from `git submodule add <shellops url> shell/.ops && shell/.ops/init`.")

  return root, None


def reply(payload):
  return json.dumps(payload, ensure_ascii=False)


def failure(message, **extra):
  return reply({"ok": False, "error": message, **extra})


def workshop_project(args, **kwargs):
  """What the project declares and what its toolchain looks like right now."""
  root, error = project_for(args)
  if error:
    return failure(error)

  check = ops.run(root, ["install", "--check"], timeout_of(args))
  return reply({
    "ok": check["ok"],
    "root": str(root),
    "summary": summary_line(root),
    "declaration": declaration(root),
    "release": release(root),
    "declared": [{"channel": c, "tool": t, "version": v} for c, t, v in declared_tools(root)],
    "toolchain": ops.check_table(check),
    "stderr": check["stderr"],
  })


def workshop_install(args, **kwargs):
  """Checks the declared tools, or installs the missing ones, or the ones named."""
  root, error = project_for(args)
  if error:
    return failure(error)

  command = ["install"]
  if args.get("check", True):
    command.append("--check")

  command += [str(tool) for tool in args.get("tools") or []]
  outcome = ops.run(root, command, timeout_of(args))
  outcome["root"] = str(root)
  if args.get("check", True):
    outcome["toolchain"] = ops.check_table(outcome)

  return reply(outcome)


def workshop_test(args, **kwargs):
  """The test plan for changed paths, the run of those paths, or the full suite."""
  root, error = project_for(args)
  if error:
    return failure(error)

  verb = args.get("verb", "plan")
  if verb not in ("plan", "files", "all"):
    return failure(f"verb must be plan, files or all, not {verb!r}")

  command = ["test", verb, *[str(p) for p in args.get("paths") or []]]
  outcome = ops.run(root, command, timeout_of(args))
  outcome["root"] = str(root)
  return reply(outcome)


def workshop_lint(args, **kwargs):
  """The house-style lint over the paths named, or the whole project."""
  root, error = project_for(args)
  if error:
    return failure(error)

  command = ["lint", *[str(p) for p in args.get("paths") or []]]
  outcome = ops.run(root, command, timeout_of(args))
  outcome["root"] = str(root)
  return reply(outcome)


def timeout_of(args):
  """The call's own timeout_seconds when it gives one, else the ops_timeout_seconds setting."""
  try:
    return int(args.get("timeout_seconds") or settings.value("ops_timeout_seconds"))
  except (TypeError, ValueError):
    return settings.value("ops_timeout_seconds")


REGISTRY = [
  (PROJECT_SCHEMA, workshop_project),
  (INSTALL_SCHEMA, workshop_install),
  (TEST_SCHEMA, workshop_test),
  (LINT_SCHEMA, workshop_lint),
]
