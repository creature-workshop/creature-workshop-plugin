"""The tools the agent calls, one per lifecycle verb, each a thin wrapper of shell/ops.

Every handler takes the tool's arguments as a mapping and returns a JSON string,
on success and on failure alike, and never raises: Hermes shows the agent
whatever comes back. Every handler works on the project the session is on,
which workshop.agent.session finds from the session id Hermes passes with
the call. No tool changes which project that is: only the user does, in
the Workshop pane.
"""

import json

from .. import settings
from ..consent import require_consent
from ..project import check_table
from ..project.declaration import declaration, declared_tools, release, summary_line
from ..run import ops
from . import guard, session
from .schemas import INSTALL_SCHEMA, LINT_SCHEMA, PROJECT_SCHEMA, TEST_SCHEMA


def project_for(call):
  """(root, error) for the project the calling session is on; one of the two is None.
  call is what Hermes passes a handler beside the tool's arguments."""

  return session.project(session_of(call))


def session_of(call):
  """The id of the session a tool call came from, or "" when Hermes passed none."""

  return str(call.get("session_id") or "")


def reply(payload):
  """A tool's answer as Hermes takes it: the payload as a JSON string."""

  return json.dumps(payload, ensure_ascii=False)


def failure(message, **extra):
  """A tool's answer for a failure: ok false, the message, and any extra fields."""

  return reply({"ok": False, "error": message, **extra})


def workshop_project(args, **kwargs):
  """What the project declares and what its toolchain looks like right now."""

  root, error = project_for(kwargs)
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
    "toolchain": check_table.rows(check),
    "stderr": check["stderr"],
  })


def workshop_install(args, **kwargs):
  """Checks the declared tools, or installs the missing ones, or the ones named."""

  root, error = project_for(kwargs)
  if error:
    return failure(error)

  denial = require_consent(root)
  if denial is not None:
    return failure(denial)

  command = ["install"]
  if args.get("check", True):
    command.append("--check")

  command += [str(tool) for tool in args.get("tools") or []]
  outcome = ops.run(root, command, timeout_of(args))
  outcome["root"] = str(root)
  if args.get("check", True):
    outcome["toolchain"] = check_table.rows(outcome)
  else:
    guard.forget(root)

  return reply(outcome)


def workshop_test(args, **kwargs):
  """The test plan for changed paths, the run of those paths, or the full suite."""

  root, error = project_for(kwargs)
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

  root, error = project_for(kwargs)
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


def registry():
  """Every tool as (schema, handler), in the order register hands them to Hermes."""

  return [
    (PROJECT_SCHEMA, workshop_project),
    (INSTALL_SCHEMA, workshop_install),
    (TEST_SCHEMA, workshop_test),
    (LINT_SCHEMA, workshop_lint),
  ]
