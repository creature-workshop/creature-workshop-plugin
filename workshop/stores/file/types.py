"""Which JSON Schema types a value is, and which types a definition allows.

    types_of(False)  ->  {"boolean"}
    types_of(3)      ->  {"integer", "number"}
    allowed_types({"type": ["string", "null"]})  ->  {"string", "null"}
"""

def types_of(value):
  """The JSON Schema types value belongs to."""

  if value is None:
    return {"null"}

  if isinstance(value, bool):
    return {"boolean"}

  if isinstance(value, int):
    return {"integer", "number"}

  if isinstance(value, float):
    return {"number"}

  if isinstance(value, str):
    return {"string"}

  if isinstance(value, list):
    return {"array"}

  return {"object"}


def allowed_types(definition):
  """The types definition allows; empty when it names none, which allows any."""

  declared = definition.get("type", [])
  return set(declared) if isinstance(declared, list) else {declared}
