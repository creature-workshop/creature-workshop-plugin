"""What a kind of file answers other than a plain success, each with a code and the HTTP status it stands for.

A kind raises one of these, and the /file routes answer it the way a
GraphQL server answers an error: `data` is null, and `errors` holds one error
whose `message` is the reason and whose `extensions` carry the code, the
status and anything else the outcome carries, such as the current record.
Desktop's transport cannot carry a 3xx to a plugin, so a 3xx outcome travels
as HTTP 200 with its own status in the extensions; every other outcome uses
its status as the HTTP status too.

A 4xx means the request was wrong and the user can fix it; a 5xx means the
backend or the service behind it failed and the user cannot.
"""

class FileOutcome(Exception):
  """An outcome other than a plain success: its code, its HTTP status, the reason for the user, and anything else it carries."""

  code = "FILE_FAILURE"
  status = 500

  def __init__(self, reason, **carried):
    """Keeps the reason and whatever else the outcome carries, such as the current record."""

    super().__init__(reason)
    self.reason = reason
    self.carried = carried

  def body(self):
    """The answer's body, as a GraphQL server answers an error: no data, and one error with the reason, the code, the status and what it carries."""

    extensions = {"code": self.code, "status": self.status, **self.carried}
    return {"data": None, "errors": [{"message": self.reason, "extensions": extensions}]}


class Unchanged(FileOutcome):
  """A read that named the revision the caller already has, when nothing changed since."""

  code = "UNCHANGED"
  status = 304


class Moved(FileOutcome):
  """The record or key moved; carries `source`, `id` and `key` where it lives now. A write that moved is a 308."""

  code = "MOVED"
  status = 301


class MovedForWrite(Moved):
  """A write to a record or key that moved: send the same write to where it lives now."""

  status = 308


class Refused(FileOutcome):
  """The schema or the request says no; the reason says why."""

  code = "REFUSED"
  status = 400


class NotFound(FileOutcome):
  """The record does not exist."""

  code = "NOT_FOUND"
  status = 404


class Unsupported(FileOutcome):
  """The kind does not do this operation, such as creating a record in a file that is one document."""

  code = "UNSUPPORTED"
  status = 405


class Stale(FileOutcome):
  """The record changed since the revision the write named; carries the current `record`."""

  code = "STALE"
  status = 409


class Gone(FileOutcome):
  """The record or key was removed and has no successor."""

  code = "GONE"
  status = 410


class FileFailure(FileOutcome):
  """The backend itself failed: a file it cannot read, a disk error, a bug."""

  code = "FILE_FAILURE"
  status = 500


class Upstream(FileOutcome):
  """The service a kind reads its files from failed (502), is unavailable (503) or timed out (504)."""

  code = "UPSTREAM"
  status = 502
