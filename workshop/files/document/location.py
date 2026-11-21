"""Where a document's source is: `config/<name>.yaml` under the project's .ops/.

    document_path(root, "config/manifest.yaml")  ->  root/.ops/config/manifest.yaml
"""

import re

from workshop.files.outcomes import Refused

SOURCE = re.compile(r"^config/[a-z0-9][a-z0-9-]*\.yaml$")

RECORD_ID = "document"


def document_path(root, source):
  """The file under root/.ops/ that source names; raises outcomes.Refused for a source that is not a document."""

  if not SOURCE.match(source):
    raise Refused(f"{source} is not a document: a document is config/<name>.yaml under .ops/.")

  return root / ".ops" / source


def stem_of(source):
  """The document's name without its folder or extension: "manifest" for config/manifest.yaml."""

  return source.split("/", 1)[1].removesuffix(".yaml")
