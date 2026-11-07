"""The directory the session works in, as Hermes resolves it."""

import os


def directory():
  """The directory the session works in: Hermes's configured one, else this process's."""

  try:
    from agent.runtime_cwd import resolve_agent_cwd

    return str(resolve_agent_cwd())
  except Exception:
    return os.getcwd()
