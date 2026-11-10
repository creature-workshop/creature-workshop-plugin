"""The stores by kind, which the /store routes serve.

    register("file", FileStore())
    store_for("file")  ->  the FileStore
"""

from workshop.stores.outcomes import NotFound

STORES = {}


def register(kind, store):
  """Makes store the one the routes use for kind, replacing any before it, and hands it back."""

  STORES[kind] = store
  return store


def store_for(kind):
  """The store registered for kind; raises outcomes.NotFound when there is none."""

  if kind not in STORES:
    raise NotFound(f"There is no store of kind {kind}. The kinds are: {', '.join(sorted(STORES))}.")

  return STORES[kind]
