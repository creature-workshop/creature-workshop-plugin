"""The last two passes over a file: a verb at the tail of a pipeline
answers inside a brace group, and in a bats file `run @verb` goes through
the `printing` helper so the test still reads the answer in $output.
"""

from patterns import BATS_RUN, PIPE_TAIL
from statements import enclosing_function, out_variable


def rewrite_pipe_tails(text, value_verbs, in_bats):
  """(text, rewrites) with `... | @verb args` at the end of a line as `... | { @verb out args; println "$out"; }`."""

  rewrites = 0

  def replacement(match):
    nonlocal rewrites
    if match.group(2) not in value_verbs:
      return match.group(0)

    rewrites += 1
    out = out_variable(enclosing_function(text, match.start()), in_bats)
    return f'{match.group(1)}{{ @{match.group(2)} {out} {match.group(3)}; println "${out}"; }}'

  return PIPE_TAIL.sub(replacement, text), rewrites


def rewrite_bats_runs(text, value_verbs):
  """(text, rewrites) with `run @verb args` as `run printing @verb args`."""

  rewrites = 0

  def replacement(match):
    nonlocal rewrites
    if match.group(2) not in value_verbs:
      return match.group(0)

    rewrites += 1
    return f"{match.group(1)}printing @{match.group(2)}"

  return BATS_RUN.sub(replacement, text), rewrites
