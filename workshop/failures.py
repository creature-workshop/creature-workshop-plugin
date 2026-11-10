"""How every route of the plugin answers a failure: the way a GraphQL server
answers an error, as the /store routes already do, so the pane reads one
shape whichever route failed.

    {
      "data": null,
      "errors": [{
        "message": "No repository at /tmp/gone.",
        "extensions": { "code": "NOT_FOUND", "status": 404 }
      }]
    }

A route that raises FastAPI's HTTPException answers its status, with the
detail as the message and a code named for the status. Any other exception
is a bug in the backend: it answers 500 with the code INTERNAL, and the
exception is logged under the `creature-workshop` logger with its traceback.
"""

import functools
import logging

from fastapi import HTTPException
from fastapi.responses import JSONResponse

log = logging.getLogger("creature-workshop")

CODES = {400: "REFUSED", 404: "NOT_FOUND", 405: "UNSUPPORTED", 409: "STALE"}
"""The code an HTTP status stands for; any other status is INTERNAL."""


def error_body(message, code, status):
  """The body of a failure: no data, and one error with the message, the code and the status."""

  return {"data": None, "errors": [{"message": message, "extensions": {"code": code, "status": status}}]}


def answered(handler):
  """handler, answering a failure in the shared shape instead of raising it.

  The wrapper keeps handler's name and signature, so FastAPI reads the same
  parameters from it.
  """

  @functools.wraps(handler)
  async def answer(*args, **kwargs):
    """What handler answers, or the failure it raised, in the shared shape."""

    try:
      return await handler(*args, **kwargs)
    except HTTPException as error:
      return refusal(error)
    except Exception as error:  # noqa: BLE001 - every other exception is a bug, answered and logged
      return internal(handler, error)

  return answer


def refusal(error):
  """The answer for an HTTPException: its status, its detail as the message, and the code for the status."""

  status = error.status_code
  body = error_body(str(error.detail), CODES.get(status, "INTERNAL"), status)
  return JSONResponse(status_code=status, content=body)


def internal(handler, error):
  """The answer for an exception no route expected: 500 INTERNAL, after logging it with its traceback."""

  log.exception("%s failed", handler.__name__)
  message = f"{type(error).__name__}: {error}"
  return JSONResponse(status_code=500, content=error_body(message, "INTERNAL", 500))
