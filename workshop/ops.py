"""Running a project's shell/ops and reading what it prints.

Every command runs in the project's root with its .envrc loaded, which is how
shellops finds the project, and reports the same shape whether it succeeded,
failed or timed out, so a tool can hand the result straight to the agent.
What `install --check` prints is read by check_table. Every run is
logged under the `creature-workshop` logger, which Hermes writes
to ~/.hermes/logs/: a success at INFO into agent.log, a failure at WARNING
with its stderr into errors.log as well, so `hermes logs` shows what the
plugin ran and what went wrong.
"""

import logging
import subprocess
import time
from pathlib import Path

from . import settings

log = logging.getLogger("creature-workshop")


def run(root, args, timeout_seconds=None):
  """Runs `shell/ops <args>` in the project and returns what happened. Without a
  timeout of its own, the call gets the ops_timeout_seconds setting.

    run(root, ["install", "--check"])  ->  {"ok": True, "command": "shell/ops install --check",
                        "stdout": "...", "stderr": "", "duration_ms": 1830}
  """

  command = ["shell/ops", *args]
  started = time.monotonic()
  limit = limit_of(timeout_seconds)
  completed, failure = attempted(lambda: dispatch(root, command, limit))
  if failure is not None:
    return logged(result(command, False, failure.stdout, failure.message, started))

  return logged(result(command, completed.returncode == 0, completed.stdout, completed.stderr, started))


def logged(outcome):
  """The outcome, after logging it: INFO when the command succeeded, WARNING with
  its stderr when it did not."""

  if outcome["ok"]:
    log.info("%s in %dms", outcome["command"], outcome["duration_ms"])
  else:
    log.warning("%s failed in %dms: %s", outcome["command"], outcome["duration_ms"], outcome["stderr"].strip())

  return outcome


def limit_of(timeout_seconds):
  """The timeout the caller gave, or the ops_timeout_seconds setting when it gave none."""

  if timeout_seconds is not None:
    return timeout_seconds

  return settings.value("ops_timeout_seconds")


def dispatch(root, command, timeout_seconds):
  """Runs the command in the project with its .envrc loaded, the way a terminal there would."""

  return subprocess.run(
    ["bash", "-c", 'source ./.envrc >/dev/null 2>&1; exec "$@"', "ops", *command],
    cwd=str(root),
    capture_output=True,
    text=True,
    timeout=timeout_seconds,
  )


class Failure:
  """Why a dispatch did not complete: the message for the caller, and whatever
  stdout the command had written by then."""

  def __init__(self, message, stdout=""):
    self.message = message
    self.stdout = stdout


def attempted(call):
  """(value, None) when the call completes, (None, Failure) when the command
  timed out or could not start. The one place a dispatch's exceptions are
  caught, so run reads straight down."""

  try:
    return call(), None
  except subprocess.TimeoutExpired as error:
    return None, Failure(f"timed out after {error.timeout}s", text_of(error.stdout))
  except OSError as error:
    return None, Failure(str(error))


def result(command, ok, stdout, stderr, started):
  return {
    "ok": ok,
    "command": " ".join(command),
    "stdout": text_of(stdout),
    "stderr": text_of(stderr),
    "duration_ms": int((time.monotonic() - started) * 1000),
  }


def text_of(value):
  """A stream's output as text: bytes decoded, None as the empty string."""

  if isinstance(value, bytes):
    return value.decode("utf-8", "replace")

  return value or ""
