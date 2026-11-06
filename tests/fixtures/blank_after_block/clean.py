"""A module whose multi-line statements all have their blank line, and whose
definitions and docstrings follow PEP 8."""
TABLE = {
  "one": 1,
  "two": 2,
}


def clean(value):
  """The docstring is followed by code at once."""
  if value:
    value = value + 1
  elif value is None:
    value = 0
  else:
    value = -1

  return value


def ends_the_block(value):
  for item in value:
    if item:
      return item

  return None


def multi_line_call(value):
  result = clean(
    value,
  )

  return result
