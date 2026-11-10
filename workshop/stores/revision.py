"""A record's revision: what changes whenever its data changes."""

import hashlib


def revision_of(data):
  """The revision of data, the bytes a record is stored as: their sha256, in hex."""

  return hashlib.sha256(data).hexdigest()
