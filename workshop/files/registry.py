"""The kinds of file the /file routes serve, by name.

    register("document", DocumentFiles())
    files_of("document")  ->  the DocumentFiles
"""

from workshop.files.outcomes import NotFound

KINDS = {}


def register(kind, files):
  """Makes files the one the routes use for kind, replacing any before it, and hands it back."""

  KINDS[kind] = files
  return files


def files_of(kind):
  """The Files registered for kind; raises outcomes.NotFound when there is none."""

  if kind not in KINDS:
    raise NotFound(f"There is no kind of file named {kind}. The kinds are: {', '.join(sorted(KINDS))}.")

  return KINDS[kind]
