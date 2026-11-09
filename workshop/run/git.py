"""Running git for the plugin: one command in one directory, its output or nothing."""

import subprocess

TIMEOUT_SECONDS = 10


def git(root, *args):
  """What `git <args>` prints at root, stripped, or "" when git fails, is missing or takes too long.

    git("/home/someone/demo", "rev-parse", "--abbrev-ref", "HEAD")  ->  "main"
  """

  try:
    done = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, timeout=TIMEOUT_SECONDS)
  except (OSError, subprocess.TimeoutExpired):
    return ""

  if done.returncode != 0:
    return ""

  return done.stdout.strip()
