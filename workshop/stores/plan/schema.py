"""The JSON Schema of a ticket in a plan file, which names the states that plan has.

    schema_for({})["properties"]["state"]["enum"]  ->  ["backlog", "todo", "in_progress", "in_review", "done", "cancelled"]
"""

from workshop.stores.plan.document import default_state, states_of

TEXT = ["string", "null"]


def schema_for(document):
  """The schema of a ticket of document: a title, and whatever else of the state, the description, the milestone, the lane, the assignee, the estimate, the priority and the blockers it sets."""

  return {
    "type": "object",
    "required": ["title"],
    "properties": {
      "title": {"type": "string", "description": "What the ticket is for, in one line."},
      "state": {"type": "string", "enum": states_of(document), "default": default_state(document), "description": "How far along the ticket is."},
      "description": {"type": TEXT, "description": "The ticket in full: what is wanted and how to tell it is done."},
      "milestone": {"type": TEXT, "description": "The milestone the ticket sits under."},
      "lane": {"type": TEXT, "description": "The column the ticket stacks in, such as the feature it belongs to."},
      "assignee": {"type": TEXT, "description": "Who is working on the ticket."},
      "estimate": {"type": ["number", "null"], "description": "How much attention the ticket takes, in hours."},
      "priority": {"type": ["integer", "null"], "description": "How urgent the ticket is; 1 is the most urgent."},
      "blocked_by": {"type": "array", "items": {"type": "string"}, "description": "The keys of the tickets that must be done before this one."},
    },
  }
