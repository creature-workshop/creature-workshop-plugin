"""A file whose docstrings each have one blank line after them."""

LIMIT = 3


def add_limit(value):
  """Adds the limit."""

  return value + LIMIT


class Counter:
  """Counts."""

  def __init__(self):
    """Starts at nothing."""

    self.count = 0

  def only_doc(self):
    """A body that is only its docstring needs no blank line."""
