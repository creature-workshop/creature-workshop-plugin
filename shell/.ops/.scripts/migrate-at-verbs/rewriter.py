"""The rewrite of one file from the printing shape to the register shape,
in passes: the bare statements first, then the substitutions, then the
pipeline tails, and in a bats file the `run` lines.
"""

from bare_statements import rewrite_bare_statements
from substitutions import rewrite_substitutions
from tails import rewrite_bats_runs, rewrite_pipe_tails


def rewrite(path, text, value_verbs):
  """(text, rewrites, lines left for hand) with every call of a value verb in the register shape."""

  in_bats = path.endswith(".bats")
  text, bare = rewrite_bare_statements(text, value_verbs, in_bats)
  text, substitutions, flagged_lines = rewrite_substitutions(text, value_verbs, in_bats)
  text, tails = rewrite_pipe_tails(text, value_verbs, in_bats)
  runs = 0
  if in_bats:
    text, runs = rewrite_bats_runs(text, value_verbs)

  return text, bare + substitutions + tails + runs, flagged_lines
