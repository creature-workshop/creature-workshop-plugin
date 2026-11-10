"""The /store routes, which serve every registered store the same way, named
and shaped after GraphQL's operations so that a GraphQL endpoint can replace
them later:

- GET /store/introspect?kind=&root=&source=: the JSON Schema of the records,
  as `{data: {schema}}`.
- GET /store/query?kind=&root=&source=&id=&revision=: one record as
  `{data: {record}}`, or every record as `{data: {records}}` when there is no
  id. With the revision the caller has, the UNCHANGED error when nothing
  changed since.
- POST /store/mutate: one operation (a MutateBody). set, clear and reset
  answer `{data: {record}}` after the change; create answers it with HTTP
  201; delete answers `{data: {deleted: {id}}}`.

`kind` names the store (workshop.stores.registry) and `source` what it reads,
such as config/manifest.yaml for the file store. `root` must be the root of
a shellops project. An outcome other than a plain success answers its own
status, with `{data: null, errors: [...]}` as workshop.stores.outcomes
shapes it. A 3xx outcome answers HTTP 200 with its own status in the error's
extensions, since Desktop's transport drops a 3xx before the plugin sees it.
"""

from pathlib import Path

from fastapi import Query
from fastapi.responses import JSONResponse

from workshop import api
from workshop.models.store import Answer, MutateBody
from workshop.project.declaration import find_project
from workshop.stores import kinds, registry
from workshop.stores.contract import Change
from workshop.stores.outcomes import Refused, StoreOutcome

NEEDS = {
  "set": ("id", "revision", "key"),
  "clear": ("id", "revision", "key"),
  "reset": ("id", "revision", "key"),
  "create": (),
  "delete": ("id", "revision"),
}


@api.register("/store/introspect", Answer)
async def introspect(kind: str = Query(), root: str = Query(), source: str = Query()):
  """The JSON Schema of the records in source."""

  return answered(lambda store, project: Answer(data={"schema": store.describe(project, source)}), kind, root)


@api.register("/store/query", Answer)
async def query(kind: str = Query(), root: str = Query(), source: str = Query(), id: str = Query(default=""), revision: str = Query(default="")):
  """One record when id is given, every record otherwise."""

  def asked(store, project):
    """The record or the records."""

    if not id:
      return Answer(data={"records": store.list(project, source)})

    return Answer(data={"record": store.read(project, source, id, revision or None)})

  return answered(asked, kind, root)


@api.register("/store/mutate", Answer, method="POST")
async def mutate(body: MutateBody):
  """One operation on the records in body.source."""

  return answered(lambda store, project: mutated(store, project, body), body.kind, body.root)


def mutated(store, project, body):
  """The answer of body's operation, once the body carries what the operation needs."""

  missing = [field for field in NEEDS[body.op] if not getattr(body, field)]
  if missing:
    raise Refused(f"A {body.op} needs {', '.join(missing)}.")

  operations = {"create": created, "delete": deleted}
  return operations.get(body.op, changed)(store, project, body)


def changed(store, project, body):
  """A set, clear or reset: the record after it."""

  change = Change(op=body.op, key=body.key, value=body.value)
  return Answer(data={"record": store.write(project, body.source, body.id, change, body.revision)})


def created(store, project, body):
  """A create: the new record, with HTTP 201."""

  record = store.create(project, body.source, body.values)
  return JSONResponse(status_code=201, content={"data": {"record": record}})


def deleted(store, project, body):
  """A delete: the id of the record removed."""

  store.delete(project, body.source, body.id, body.revision)
  return Answer(data={"deleted": {"id": body.id}})


def answered(act, kind, root):
  """act(store, project root) for the store of kind and the project rooted at root, or the answer for the outcome it raised."""

  try:
    return act(registry.store_for(kind), project_root(root))
  except StoreOutcome as outcome:
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
