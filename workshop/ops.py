"""Running a project's shell/ops and reading what it prints.

Every command runs in the project's root with its .envrc loaded, which is how
shellops finds the project, and reports the same shape whether it succeeded,
failed or timed out, so a tool can hand the result straight to the agent.
"""
import subprocess
import time
from pathlib import Path

from . import settings


def run(root, args, timeout_seconds=None):
  """Runs `shell/ops <args>` in the project and returns what happened. Without a
  timeout of its own, the call gets the ops_timeout_seconds setting.

    run(root, ["install", "--check"])  ->  {"ok": True, "command": "shell/ops install --check",
                        "stdout": "...", "stderr": "", "duration_ms": 1830}
  """
  command = ["shell/ops", *args]
  started = time.monotonic()
  limit = timeout_seconds if timeout_seconds is not None else settings.value("ops_timeout_seconds")
  completed, failure = attempted(lambda: dispatch(root, command, limit))
  if failure is not None:
    return result(command, False, failure.stdout, failure.message, started)

  return result(command, completed.returncode == 0, completed.stdout, completed.stderr, started)


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
  return value.decode("utf-8", "replace") if isinstance(value, bytes) else (value or "")


INSTALLED_MARK = "✓"


def check_table(outcome):
  """The text of `ops install --check` as rows. The dispatcher logs the table on
  stderr, so both streams are read."""
  return parse_check_table(outcome["stdout"] + "\n" + outcome["stderr"])


def parse_check_table(text):
  """The rows of `ops install --check` as records.

  The table is a header, a rule and one line per tool with a status mark, the
  tool, its version and its channel:

    parse_check_table("  ✓      ffmpeg    6.1.1    system\\n")
     ->  [{"tool": "ffmpeg", "version": "6.1.1", "channel": "system", "installed": True}]
  """
  rows = []
  for line in text.splitlines():
    parts = line.split()
    if len(parts) < 4 or parts[0] in ("Status",) or set(line.strip()) <= {"-"}:
      continue

    mark, tool, version, channel = parts[0], parts[1], parts[2], parts[3]
    rows.append({"tool": tool, "version": version, "channel": channel, "installed": mark == INSTALLED_MARK})

  return rows


def envrc_present(root):
  return (Path(root) / ".envrc").is_file()
