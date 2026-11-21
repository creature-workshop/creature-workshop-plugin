"""The /file routes, which serve every kind of file the same way, named
and shaped after GraphQL's operations so that a GraphQL endpoint can replace
them later:

- GET /file/introspect?kind=&root=&source=: the JSON Schema of the records,
  as `{data: {schema}}`.
- GET /file/query?kind=&root=&source=&id=&revision=: one record as
  `{data: {record}}`, or every record as `{data: {records}}` when there is no
  id. With the revision the caller has, the UNCHANGED error when nothing
  changed since.
- POST /file/mutate: one operation (a MutateBody). set, clear and reset
  answer `{data: {record}}` after the change; create answers it with HTTP
  201; delete answers `{data: {deleted: {id}}}`.

`kind` names the kind of file (workshop.files.registry) and `source` the
file under .ops/, such as config/manifest.yaml for the document kind. `root` must be the root of
a shellops project. An outcome other than a plain success answers its own
status, with `{data: null, errors: [...]}` as workshop.files.outcomes
shapes it. A 3xx outcome answers HTTP 200 with its own status in the error's
extensions, since Desktop's transport drops a 3xx before the plugin sees it.
"""

from pathlib import Path

from fastapi import Query
from fastapi.responses import JSONResponse

from workshop import api
from workshop.models.file import Answer, MutateBody
from workshop.project.declaration import find_project
from workshop.files import kinds, registry
from workshop.files.contract import Change
from workshop.files.outcomes import Refused, FileOutcome

NEEDS = {
  "set": ("id", "revision", "key"),
  "clear": ("id", "revision", "key"),
  "reset": ("id", "revision", "key"),
  "create": (),
  "delete": ("id", "revision"),
}


@api.register("/file/introspect", Answer)
async def introspect(kind: str = Query(), root: str = Query(), source: str = Query()):
  """The JSON Schema of the records in source."""

  return answered(lambda files, project: Answer(data={"schema": files.describe(project, source)}), kind, root)


@api.register("/file/query", Answer)
async def query(kind: str = Query(), root: str = Query(), source: str = Query(), id: str = Query(default=""), revision: str = Query(default="")):
  """One record when id is given, every record otherwise."""

  def asked(files, project):
    """The record or the records."""

    if not id:
      return Answer(data={"records": files.list(project, source)})

    return Answer(data={"record": files.read(project, source, id, revision or None)})

  return answered(asked, kind, root)


@api.register("/file/mutate", Answer, method="POST")
async def mutate(body: MutateBody):
  """One operation on the records in body.source."""

  return answered(lambda files, project: mutated(files, project, body), body.kind, body.root)


def mutated(files, project, body):
  """The answer of body's operation, once the body carries what the operation needs."""

  missing = [field for field in NEEDS[body.op] if not getattr(body, field)]
  if missing:
    raise Refused(f"A {body.op} needs {', '.join(missing)}.")

  operations = {"create": created, "delete": deleted}
  return operations.get(body.op, changed)(files, project, body)


def changed(files, project, body):
  """A set, clear or reset: the record after it."""

  change = Change(op=body.op, key=body.key, value=body.value)
  return Answer(data={"record": files.write(project, body.source, body.id, change, body.revision)})


def created(files, project, body):
  """A create: the new record, with HTTP 201."""

  record = files.create(project, body.source, body.values)
  return JSONResponse(status_code=201, content={"data": {"record": record}})


def deleted(files, project, body):
  """A delete: the id of the record removed."""

  files.delete(project, body.source, body.id, body.revision)
  return Answer(data={"deleted": {"id": body.id}})


def answered(act, kind, root):
  """act(files, project root) for the Files of kind and the project rooted at root, or the answer for the outcome it raised."""

  try:
    return act(registry.files_of(kind), project_root(root))
  except FileOutcome as outcome:
    return JSONResponse(status_code=http_status(outcome.status), content=outcome.body())


def project_root(root):
  """root resolved; raises outcomes.Refused unless it is the root of a shellops project."""

  project = Path(root).resolve()
  if find_project(project) != project:
    raise Refused(f"{root} is not the root of a shellops project.")

  return project


def http_status(status):
  """The HTTP status an outcome answers: its own, except 200 for a 3xx, which Desktop's transport would drop."""

  return 200 if 300 <= status < 400 else status
