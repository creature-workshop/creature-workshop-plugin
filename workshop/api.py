"""The registry the backend's routes are built from, the backend's mirror of
desktop/src/client/api.js.

Each module under workshop/routes/ registers its routes here with
`register`, and `router` gathers every registered route, so
dashboard/plugin_api.py mounts one router without knowing which routes exist.

    @api.register("/about", About)
    async def about():
      ...

    @api.register("/store/mutate", Answer, method="POST")
    async def mutate(body: MutateBody):
      ...
"""

from fastapi import APIRouter

from workshop.failures import answered

router = APIRouter()


def register(path, model, method="GET"):
  """A decorator that registers a function as the handler of method on path, answering with model.

  The router answers any failure the handler raises in the shared shape
  workshop.failures describes. It hands the function back unchanged, so a
  test calls the handler directly.
  """

  def add(handler):
    """Adds handler to the router under path, and hands it back."""

    router.add_api_route(path, answered(handler), methods=[method], response_model=model)
    return handler

  return add
