"""Whether a ticket of a plan takes a change, or a plan takes a new ticket.

The schema decides the key, the type and, for the state, which states the
plan has. Beyond it: a title is never blank, and a ticket is blocked only by
other tickets of the plan, each named once, with no ticket ending up blocked
by itself through the tickets that block it.
"""

from workshop.stores.contract import Change
from workshop.stores.file.checks import check_clear, check_in_enum, check_reset, check_type
from workshop.stores.outcomes import Refused
from workshop.stores.plan.document import tickets_of
from workshop.stores.plan.schema import schema_for

TITLE = "title"

BLOCKED_BY = "blocked_by"


def check_change(document, key, change):
  """Raises outcomes.Refused, with the reason, unless the ticket key of document takes change."""

  schema = schema_for(document)
  definition = schema["properties"].get(change.key)
  if definition is None:
    raise Refused(f"{change.key} is not something a ticket keeps. A ticket keeps: {', '.join(schema['properties'])}.")

  if change.op == "set":
    check_set(document, key, definition, change)
  elif change.op == "clear":
    check_clear(schema, definition, change)
  else:
    check_reset(schema, definition, change)


def check_new(document, values):
  """Raises outcomes.Refused unless values make a ticket of document: a title, and every other value one a ticket takes."""

  if TITLE not in values:
    raise Refused("A ticket needs a title.")

  for name, value in values.items():
    check_change(document, None, Change("set", name, value))


def check_set(document, key, definition, change):
  """Raises unless the value is of a type the key allows, a state the plan has, a title with text in it, or blockers the ticket can have."""

  check_type(definition, change.key, change.value)
  check_in_enum(definition, change.key, change.value)
  if change.key == TITLE and not change.value.strip():
    raise Refused("A ticket needs a title.")

  if change.key == BLOCKED_BY:
    check_blockers(document, key, change.value)


def check_blockers(document, key, blockers):
  """Raises unless blockers are keys of other tickets of document, each once, none of them blocked by the ticket key itself."""

  blocked_by = {str(ticket["key"]): [str(each) for each in ticket.get(BLOCKED_BY) or []] for ticket in tickets_of(document)}
  for blocker in blockers:
    check_blocker(blocked_by, key, blocker)

  if len(set(blockers)) != len(blockers):
    raise Refused("A ticket names each ticket that blocks it once.")


def check_blocker(blocked_by, key, blocker):
  """Raises unless blocker is a string naming another ticket of the plan that the ticket key does not block, directly or through others."""

  if not isinstance(blocker, str) or blocker not in blocked_by:
    raise Refused(f"The plan has no ticket {blocker} to be blocked by.")

  if blocker == key:
    raise Refused("A ticket cannot block itself.")

  if key in behind(blocked_by, blocker):
    raise Refused(f"{blocker} is already blocked by {key}, so {key} cannot be blocked by it.")


def behind(blocked_by, key):
  """The keys of every ticket that must be done before the ticket key: its blockers, and theirs, all the way back."""

  seen = set()
  waiting = list(blocked_by.get(key, []))
  while waiting:
    each = waiting.pop()
    if each not in seen:
      seen.add(each)
      waiting.extend(blocked_by.get(each, []))

  return seen
