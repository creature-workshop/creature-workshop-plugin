"""The picks kept for each chat: the repository picked for it, and the worktree
picked for each repository it has been on.

The picks are files in the plugin's data folder. Each value has a file of
its own, written in one step, so a reader never sees half of a write and two
writers never overwrite each other's value.

Hermes gives a chat a new session id when it compresses the chat.
`continued` records that the new id continues the old one, and every id of
one chat reads and writes the same picks.
"""

import hashlib
import os
import tempfile

from ..about import data

FOLDER = "selection"
REPOSITORY = "pick"
WORKTREE = "worktree"
CONTINUES = "continues"
SCRATCH_SUFFIX = ".tmp"


def pick_of(session_id, kind):
  """The pick of one kind made for the session's chat, or "" when there is none."""

  if not session_id:
    return ""

  return read(chat_of(session_id), kind)


def keep(session_id, kind, value):
  """Keeps value as the pick of one kind for the session's chat."""

  write(chat_of(session_id), kind, value)


def worktree_kind(repository_root):
  """The kind under which the worktree picked for one repository is kept, so a
  chat keeps a worktree for each repository it has been on."""

  return f"{WORKTREE}-{hashlib.sha256(repository_root.encode()).hexdigest()[:16]}"


def continued(session_id, earlier_session_id):
  """Records that session_id continues the chat of earlier_session_id, so both
  ids read and write the same picks. Picks already made under session_id are
  the later ones, so they become the chat's picks. Does nothing when either
  id is empty, or when both already belong to one chat."""

  if not session_id or not earlier_session_id:
    return

  if chat_of(earlier_session_id) == chat_of(session_id):
    return

  later = chat_of(session_id)
  later_picks = {kind: read(later, kind) for kind in pick_kinds(later)}
  write(session_id, CONTINUES, earlier_session_id)
  for kind, value in later_picks.items():
    write(chat_of(session_id), kind, value)


def chat_of(session_id):
  """The first session id of the chat that session_id belongs to: the id itself
  until Hermes compresses the chat.

    chat_of("s3")  ->  "s1"   # s3 continues s2, and s2 continues s1
  """

  seen = [session_id]
  earlier = read(session_id, CONTINUES)
  while earlier and earlier not in seen:
    seen.append(earlier)
    earlier = read(earlier, CONTINUES)

  return seen[-1]


def pick_kinds(session_id):
  """The kinds of pick kept for a session id: REPOSITORY, and one for each repository a worktree was picked for."""

  stem = file_of(session_id, "")
  kinds = [path.name.removeprefix(stem.name) for path in stem.parent.glob(f"{stem.name}*")]
  return [kind for kind in kinds if kind != CONTINUES and not kind.endswith(SCRATCH_SUFFIX)]


def read(session_id, kind):
  """The value of one kind kept for a session id, or "" when there is none."""

  try:
    return file_of(session_id, kind).read_text().strip()
  except OSError:
    return ""


def write(session_id, kind, value):
  """Keeps value as the one of its kind for a session id, replacing the file in
  one step so that a reader sees the old value or the new one."""

  path = file_of(session_id, kind)
  path.parent.mkdir(parents=True, exist_ok=True)
  handle, scratch = tempfile.mkstemp(dir=path.parent, prefix=path.name, suffix=SCRATCH_SUFFIX)
  with os.fdopen(handle, "w") as file:
    file.write(value + "\n")

  os.replace(scratch, path)


def file_of(session_id, kind):
  """The file that keeps one kind of value for a session id. The id is hashed,
  so whatever characters it has, the name is a safe file name."""

  name = hashlib.sha256(session_id.encode()).hexdigest()
  return data.data_dir() / FOLDER / f"{name}.{kind}"
