"""The state of one file in git: how the copy in the working tree differs
from the commit the checkout is on.

shell/actions/git/file-state reads it, through the shell/lib/git/file_state
module. This module runs that action and hands back the word it printed.

    state_of("/home/someone/demo", "/home/someone/demo/.ops/config/manifest.yaml")  ->  "modified"

The words are "clean", "modified", "new" (the commit has no copy of the
file), "deleted" and "conflict", and "none" when git has nothing to say
about the file: git ignores it, there is no file and the commit has none,
or the folder is not in a repository.
"""

import subprocess
from pathlib import Path

from ..run.environment import child_env

ACTION = Path(__file__).resolve().parents[2] / "shell" / "actions" / "git" / "file-state"

TIMEOUT_SECONDS = 10

NOTHING = "none"


def state_of(root, path):
  """The word the action prints for the file at path, in the checkout at root, or "none" when the action fails."""

  try:
    done = subprocess.run([str(ACTION), str(root), str(path)], capture_output=True, text=True, timeout=TIMEOUT_SECONDS, env=child_env())
  except (OSError, subprocess.TimeoutExpired):
    return NOTHING

  if done.returncode != 0:
    return NOTHING

  return done.stdout.strip()
