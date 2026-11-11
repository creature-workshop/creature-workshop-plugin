"""The plan file as a document: its tickets, its states and the key its next ticket takes.

A project with no plan file has an empty plan, and the first ticket creates
the file. The file may name its own `states`, each `{name, type}`, and the
`prefix` of its keys; without them the states are DEFAULT_STATES and the
prefix is DEFAULT_PREFIX, as in shellops' file tracker. Every write rewrites
the whole file, so a comment in it is not kept.
"""

from workshop.project.yaml_loader import dump_yaml, load_yaml
from workshop.stores.outcomes import NotFound, StoreFailure
from workshop.stores.plan.location import plan_path

DEFAULT_STATES = ("backlog", "todo", "in_progress", "in_review", "done", "cancelled")

DEFAULT_PREFIX = "PLAN"

TODO = "todo"


def load(root, source):
  """The plan file of source as a mapping, {} when the project has none yet; raises outcomes.StoreFailure when it does not parse to a mapping."""

  path = plan_path(root, source)
  if not path.is_file():
    return {}

  try:
    loaded = load_yaml(path.read_text())
  except ImportError:
    raise
  except Exception as error:
    raise StoreFailure(f".ops/{source} does not parse: {error}") from error

  if loaded is None:
    return {}

  if not isinstance(loaded, dict):
    raise StoreFailure(f".ops/{source} does not hold a mapping of keys to values.")

  return loaded


def save(root, source, document):
  """Rewrites the plan file of source from document, creating its folder when it is new."""

  path = plan_path(root, source)
  path.parent.mkdir(parents=True, exist_ok=True)
  path.write_text(dump_yaml(document))


def tickets_of(document):
  """The document's tickets, in the file's order: each entry of `tickets` that is a mapping with a key."""

  return [ticket for ticket in document.get("tickets") or [] if isinstance(ticket, dict) and ticket.get("key") is not None]


def ticket_of(document, key):
  """The ticket of document whose key is key; raises outcomes.NotFound when the plan has none."""

  for ticket in tickets_of(document):
    if str(ticket["key"]) == key:
      return ticket

  raise NotFound(f"The plan has no ticket {key}.")


def states_of(document):
  """The names of the states a ticket of document can be in, in the plan's order: the ones the file names, else DEFAULT_STATES."""

  declared = [str(state["name"]) for state in document.get("states") or [] if isinstance(state, dict) and state.get("name")]
  return declared or list(DEFAULT_STATES)


def default_state(document):
  """The state a ticket of document is in when it names none: the first state of type todo, else the first state."""

  for state in document.get("states") or []:
    if isinstance(state, dict) and state.get("name") and state.get("type") == TODO:
      return str(state["name"])

  states = states_of(document)
  return TODO if TODO in states else states[0]


def next_key(document):
  """The key the next ticket of document takes: its prefix, a dash, and one past the highest number a key of that prefix carries.

    next_key({"prefix": "T", "tickets": [{"key": "T-1"}, {"key": "T-2"}]})  ->  "T-3"
  """

  prefix = str(document.get("prefix") or DEFAULT_PREFIX)
  numbers = [number_of(str(ticket["key"]), prefix) for ticket in tickets_of(document)]
  return f"{prefix}-{max(numbers, default=0) + 1}"


def number_of(key, prefix):
  """The number the key carries after prefix and a dash; 0 for a key of another prefix or with no number."""

  head, _, tail = key.rpartition("-")
  return int(tail) if head == prefix and tail.isdigit() else 0
