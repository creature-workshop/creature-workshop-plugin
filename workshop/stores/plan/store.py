"""The plan store: fills the Store contract for a plan file under .ops/data/.

Each ticket is a record whose id is the ticket's key and whose values are
the rest of the ticket as the file has it. A ticket's revision is the sha256
of the ticket alone, so a change to one ticket does not make a write to
another stale. A project with no plan file lists no records, and creating
the first ticket writes the file. Deleting a ticket also drops it from the
blockers of every other ticket.
"""

import json

from workshop.stores.contract import Store
from workshop.stores.outcomes import Stale, Unchanged
from workshop.stores.plan.checks import BLOCKED_BY, check_change, check_new
from workshop.stores.plan.document import default_state, load, next_key, save, ticket_of, tickets_of
from workshop.stores.plan.schema import schema_for
from workshop.stores.revision import revision_of

KEY = "key"

STATE = "state"


class PlanStore(Store):
  """A plan file under .ops/data/ as one record per ticket, described by a schema that names the plan's states."""

  def describe(self, root, source):
    """The schema of a ticket of the plan."""

    return schema_for(load(root, source))

  def list(self, root, source):
    """Every ticket, in the file's order; none when the project has no plan file yet."""

    return [record_of(ticket) for ticket in tickets_of(load(root, source))]

  def read(self, root, source, record_id, revision=None):
    """The ticket record_id as a record; raises outcomes.Unchanged when revision is its current revision."""

    record = record_of(ticket_of(load(root, source), record_id))
    if revision and revision == record["revision"]:
      raise Unchanged("Nothing changed since that revision.", revision=revision)

    return record

  def write(self, root, source, record_id, change, revision):
    """Applies change to the ticket made at revision, and answers the ticket after it."""

    document = load(root, source)
    ticket = current(document, record_id, revision)
    check_change(document, record_id, change)
    apply(ticket, change)
    save(root, source, document)
    return record_of(ticket)

  def create(self, root, source, values):
    """A new ticket holding values, under the plan's next key, in the plan's default state when values name none."""

    document = load(root, source)
    check_new(document, values)
    ticket = {KEY: next_key(document), STATE: default_state(document), **values}
    document["tickets"] = [*(document.get("tickets") or []), ticket]
    save(root, source, document)
    return record_of(ticket)

  def delete(self, root, source, record_id, revision):
    """Removes the ticket made at revision, and drops it from the blockers of every other ticket."""

    document = load(root, source)
    ticket = current(document, record_id, revision)
    document["tickets"] = [unblocked(each, record_id) for each in document["tickets"] if each is not ticket]
    save(root, source, document)


def current(document, record_id, revision):
  """The ticket record_id of document; raises outcomes.NotFound when the plan has none, and outcomes.Stale, carrying the ticket as it is, when revision is not its current one."""

  ticket = ticket_of(document, record_id)
  record = record_of(ticket)
  if revision != record["revision"]:
    raise Stale("The ticket changed since it was read.", record=record)

  return ticket


def record_of(ticket):
  """The ticket as a record: its key as the id, the rest of it as the values, and the sha256 of the whole ticket as the revision."""

  values = {name: value for name, value in ticket.items() if name != KEY}
  data = json.dumps(ticket, sort_keys=True, default=str).encode()
  return {"id": str(ticket[KEY]), "revision": revision_of(data), "values": values}


def apply(ticket, change):
  """Makes change to the ticket in place: a set gives the key the value, a clear gives it null, and a reset removes it."""

  if change.op == "reset":
    ticket.pop(change.key, None)
  else:
    ticket[change.key] = change.value if change.op == "set" else None


def unblocked(ticket, key):
  """The ticket without key among its blockers, and with no blockers entry when key was the last; any other entry of the file as it was."""

  if not isinstance(ticket, dict) or key not in [str(each) for each in ticket.get(BLOCKED_BY) or []]:
    return ticket

  left = [each for each in ticket[BLOCKED_BY] if str(each) != key]
  rest = {name: value for name, value in ticket.items() if name != BLOCKED_BY}
  return {**rest, BLOCKED_BY: left} if left else rest
