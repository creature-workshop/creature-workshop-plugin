"""Functions within the limit: five parameters, a method's self left out, and *args."""


def place(kind, root, source, record_id, revision):
  """Five parameters."""


class Store:
  """A method whose self is not counted."""

  def write(self, root, source, record_id, change, revision):
    """Five parameters after self."""


def gather(first, *rest):
  """Two parameters: one named and the rest."""
