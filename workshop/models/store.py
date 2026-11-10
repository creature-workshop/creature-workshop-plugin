"""The answers and the mutation body of the /store routes, shaped like GraphQL's.

Every answer is `{data, errors}`. A record is `{id, revision, values}`,
where an untouched key is absent from `values` and a cleared one is null. On success `data` holds what was asked for
(`schema`, `record`, `records` or `deleted`) and `errors` is absent; when the
store refuses or fails, `data` is null and `errors` holds one error from
workshop.stores.outcomes.
"""

from typing import Any, Literal

from pydantic import BaseModel


class Answer(BaseModel):
  """A successful answer: `data` holds what was asked for, keyed by its name."""

  data: dict[str, Any]


class MutateBody(BaseModel):
  """The body of POST /store/mutate: where, which operation, and what it needs.

  set, clear and reset take `id`, `revision` and `key` (and set takes
  `value`); create takes `values`; delete takes `id` and `revision`.
  """

  kind: str
  root: str
  source: str
  op: Literal["set", "clear", "reset", "create", "delete"]
  id: str = ""
  revision: str = ""
  key: str = ""
  value: Any = None
  values: dict[str, Any] = {}
