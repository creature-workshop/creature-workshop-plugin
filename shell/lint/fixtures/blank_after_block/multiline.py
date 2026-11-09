def multiline(value):
  answer = {
    "found": True,
    "value": value,
  }
  if value:
    answer["more"] = True

  return answer


def call(value):
  result = multiline(
    value,
  )
  return result
