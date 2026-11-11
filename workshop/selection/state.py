"""Which repository and which checkout a chat session is on.

`state` is the only function that decides. It decides the repository first:

- the repository picked for the session, while the session's folder still
  holds one of its worktrees;
- without such a pick, the repository the session's folder is inside;
- otherwise none.

A folder that is inside no repository is on none until one is picked,
however many repositories it holds below it, even when it holds only one.
The repositories below a folder are found only to list them for that pick.

Then it decides the checkout of that repository:

- the worktree picked for it, while git still lists that worktree;
- else the worktree the session's folder is inside;
- else the repository's main worktree.

Every reader calls `state` or `selected` with the session's id and its
folder, so the user and the agent are never on different checkouts.
"""

from dataclasses import dataclass
from pathlib import Path

from ..repos import grouping
from ..repos.discovery import repos_of
from . import picks


@dataclass(frozen=True)
class Selection:
  """What a session is on, from one reading of its folder: the roots of the
  checkouts the folder holds, the root of the selected repository, and the
  root of the selected checkout. The last two are "" when the session is on none."""

  checkouts: tuple = ()
  repository: str = ""
  checkout: str = ""


def state(session_id, folder):
  """The Selection of the session with this id, working in this folder.

    state("s1", "/home/someone/code")  ->  Selection(checkouts=("/home/someone/code/demo", "/home/someone/code/site"),
                                                      repository="/home/someone/code/demo", checkout="/home/someone/demo-fix")
  """

  inside, roots = checkouts(folder)
  repository = chosen_repository(roots, picks.pick_of(session_id, picks.REPOSITORY), inside)
  if repository is None:
    return Selection(checkouts=tuple(roots))

  picked = picks.pick_of(session_id, picks.worktree_kind(repository["root"]))
  return Selection(
    checkouts=tuple(roots),
    repository=repository["root"],
    checkout=chosen_checkout(repository, picked, inside),
  )


def selected(session_id, folder):
  """The root of the checkout the session is on, or None when it is on none.

    selected("s1", "/home/someone/demo/src")  ->  Path("/home/someone/demo")
  """

  checkout = state(session_id, folder).checkout
  return Path(checkout) if checkout else None


def repositories(folder):
  """The repositories a session in folder can be on, each with its worktrees, as
  GET /repos lists them; none without a folder."""

  if not folder:
    return []

  return grouping.repositories_of(folder)[2]


def checkouts(folder):
  """(inside, roots) for a session's folder: the root of the worktree the folder
  is inside, "" when it is inside none, and the roots of the checkouts the
  folder holds, each as git names it. Nothing without a folder."""

  if not folder:
    return "", []

  inside, found = repos_of(folder)
  roots = [resolved(root) for root in found]
  return (roots[0] if inside else ""), roots


def chosen_repository(roots, pick, inside):
  """The repository a session whose folder holds these checkouts is on: the one
  rooted at pick while one of roots is a worktree of it, else the one the
  folder is inside, else None. inside is the root of the worktree the folder
  is in, "" when it is in none. A repository is {root, name, worktrees}, as
  workshop.repos.grouping builds it.

    chosen_repository(["/code/demo"], "", "/code/demo")  ->  {"root": "/code/demo", ...}
    chosen_repository(["/code/demo"], "", "")            ->  None
  """

  picked = repository_at(pick) if pick else None
  if picked and picked["root"] == pick and holds(roots, picked):
    return picked

  return repository_at(inside) if inside else None


def chosen_checkout(repository, pick, inside):
  """The root of the checkout of repository a session is on: pick while it is one
  of the repository's worktrees, else inside when it is one, else the main worktree.

    chosen_checkout(demo, "/code/demo-fix", "")  ->  "/code/demo-fix"
    chosen_checkout(demo, "/code/gone", "")      ->  "/code/demo"
  """

  roots = checkout_roots(repository)
  for candidate in (pick, inside):
    if candidate in roots:
      return candidate

  return main_root(repository)


def main_root(repository):
  """The root of the repository's main worktree, else of its first worktree, else its own root."""

  mains = [each["root"] for each in repository["worktrees"] if each["main"]]
  return (mains or checkout_roots(repository))[0]


def checkout_roots(repository):
  """The roots of the repository's worktrees, or its own root alone when git lists none."""

  return [each["root"] for each in repository["worktrees"]] or [repository["root"]]


def holds(roots, repository):
  """Whether one of roots is a checkout of the repository."""

  return any(root in roots for root in checkout_roots(repository))


def repository_at(checkout):
  """The repository the folder at checkout belongs to, as workshop.repos.grouping
  builds it; a folder git cannot read stands alone, rooted at itself."""

  return grouping.repository(checkout, grouping.common_dir(checkout) or checkout)


def resolved(root):
  """root as git names a checkout's root: absolute, with no links or `..` in it.

    resolved("~/code/demo/../site/")  ->  "/home/someone/code/site"
  """

  return str(Path(root).expanduser().resolve())
