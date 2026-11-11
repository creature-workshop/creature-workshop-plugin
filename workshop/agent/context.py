"""What the agent is told about the project its session is on, and the hooks
that keep a chat's selection with it.

Hermes builds a plugin's section of the system prompt once, when a session
starts, and keeps it for the whole session. The checkout a session is on
can change at any time, when the user picks another in the pane, so the
section only says what the tools are for, and `before_turn` tells the agent
which project the session is on at the start of every turn. Both say
nothing in a session whose folder holds no workshop, so a chat that has
nothing to do with one reads nothing from this plugin.

A chat gets a new session id when Hermes compresses it, and a subagent runs
under an id of its own. `after_compaction` and `on_subagent_start` tell
workshop.selection that the new id belongs to the same chat, so it reads the
same picks.
"""

from ..consent import is_approved
from ..project.declaration import counted, declared_tools, manifest, release, release_tail
from ..selection import picks
from . import session

PROMPT_SECTION = (
  "The workshop_* tools work on one project: the workshop selected for this session, which the Workshop "
  "pane shows to the user. Each turn says which one that is. Only the user changes it, in the pane's "
  "selectors; no tool does. workshop_project gives the declaration and the "
  "toolchain; workshop_install checks or installs the declared tools; workshop_test gives the test plan "
  "of changed paths and runs it; workshop_lint runs the house-style lint."
)


def prompt_section(session_info):
  """The plugin's section of the system prompt: what the tools are for, or
  nothing when the session's folder holds no workshop."""

  if not session.holds_a_workshop(session.standing("")):
    return ""

  return PROMPT_SECTION


def before_turn(session_id="", **kwargs):
  """Hermes's pre_llm_call hook: one short paragraph, added to the user's message,
  that says which project the session is on now, or None when there is nothing to say."""

  told = current_project(session.standing(str(session_id or "")))
  return {"context": told} if told else None


def after_compaction(session_id="", old_session_id="", **kwargs):
  """Hermes's post_compaction hook: when the compaction moved the chat to a new
  session id, the new id reads the picks the old one had."""

  picks.continued(str(session_id or ""), str(old_session_id or ""))


def on_subagent_start(parent_session_id="", child_session_id="", **kwargs):
  """Hermes's subagent_start hook: a subagent is on the project its parent session is on."""

  picks.continued(str(child_session_id or ""), str(parent_session_id or ""))


def current_project(stands):
  """What the agent reads this turn about a session that stands like this: the
  project it is on; or, when it is on none and its folder holds a workshop,
  why; or "" when its folder holds no workshop at all.

    current_project(stands)  ->  'Creature Workshop: this session is on the workshop "Demo" at /home/me/demo; it declares 2 tools. The workshop_* tools run in it.'
  """

  if stands.root is not None:
    return selected_project(stands.root)

  if session.holds_a_workshop(stands):
    return f"Creature Workshop: {session.problem_of(stands)}"

  return ""


def selected_project(root):
  """What the agent reads about the project its session is on, with the consent
  it still needs when the user has not approved the project."""

  name = manifest(root).get("name") or root.name
  told = (f'Creature Workshop: this session is on the workshop "{name}" at {root}; it declares '
      f"{counted(len(declared_tools(root)), 'tool')}{release_tail(release(root))}. The workshop_* tools run in it.")

  if is_approved(root):
    return told

  return (f"{told} It has not been approved for execution yet: before any other workshop_* tool runs "
      "in it, call workshop_install with approve: true to record the user's consent.")
