"""The state of one git repository, the way a shell prompt shows it.

shell/actions/git/status reads it, through the shell/lib/git/status module:
the branch (the first seven characters of the commit when HEAD is detached),
how far it is ahead of and behind its upstream, and how many paths are
staged, modified in the working tree, untracked or in conflict. This module
runs that action and hands back what it printed.
"""

import json
import subprocess
from pathlib import Path

ACTION = Path(__file__).resolve().parents[2] / "shell" / "actions" / "git" / "status"

TIMEOUT_SECONDS = 10


def status_of(root):
  """The state of the repository at root, or None when git cannot read it.

    status_of("/home/someone/demo")  ->  {"branch": "main", "detached": False, "upstream": True,
                                          "ahead": 1, "behind": 0, "staged": 2, "modified": 1,
                                          "untracked": 3, "conflicted": 0}
  """

  try:
    done = subprocess.run([str(ACTION), str(root)], capture_output=True, text=True, timeout=TIMEOUT_SECONDS)
  except (OSError, subprocess.TimeoutExpired):
    return None

  if done.returncode != 0:
    return None

  return json.loads(done.stdout)
