"""Covers workshop/failures.py: a route's HTTPException answers its status in
the shared error shape, any other exception answers 500 INTERNAL, a success
passes through, and FastAPI still reads the wrapped route's parameters.
"""

import asyncio
import json
import unittest

from fastapi import APIRouter, HTTPException, Query

from workshop.failures import answered


async def found(path: str = Query(default="")):
  """A route that answers what it was asked."""

  return {"asked": path}


async def missing(path: str = Query(default="")):
  """A route that raises a 404 for every path."""

  raise HTTPException(status_code=404, detail=f"No repository at {path}.")


async def broken():
  """A route with a bug."""

  raise KeyError("root")


def body_of(response):
  """A JSONResponse's status and its body, decoded."""

  return response.status_code, json.loads(response.body)


class Answered(unittest.TestCase):
  def test_passes_a_success_through(self):
    self.assertEqual(asyncio.run(answered(found)(path="/x")), {"asked": "/x"})

  def test_answers_an_http_exception_with_its_status_and_a_code_for_it(self):
    status, body = body_of(asyncio.run(answered(missing)(path="/tmp/gone")))
    self.assertEqual(status, 404)
    self.assertEqual(body, {"data": None, "errors": [{"message": "No repository at /tmp/gone.", "extensions": {"code": "NOT_FOUND", "status": 404}}]})

  def test_answers_any_other_exception_as_internal_and_logs_it(self):
    with self.assertLogs("creature-workshop", level="ERROR") as logged:
      status, body = body_of(asyncio.run(answered(broken)()))

    self.assertEqual(status, 500)
    self.assertEqual(body["errors"][0]["extensions"], {"code": "INTERNAL", "status": 500})
    self.assertEqual(body["errors"][0]["message"], "KeyError: 'root'")
    self.assertIn("broken failed", logged.output[0])

  def test_fastapi_reads_the_wrapped_route_parameters(self):
    router = APIRouter()
    router.add_api_route("/found", answered(found), methods=["GET"])
    names = [param.name for param in router.routes[0].dependant.query_params]
    self.assertEqual(names, ["path"])


if __name__ == "__main__":
  unittest.main()
