"""Where a plan store source lives: `data/<name>.yaml` under the project's .ops/.

    plan_path(root, "data/plan.yaml")  ->  root/.ops/data/plan.yaml
"""

import re

from workshop.stores.outcomes import Refused

SOURCE = re.compile(r"^data/[a-z0-9][a-z0-9-]*\.yaml$")


def plan_path(root, source):
  """The file under root/.ops/ that source names; raises outcomes.Refused for a source the plan store does not read."""

  if not SOURCE.match(source):
    raise Refused(f"{source} is not a file the plan store reads: it reads data/<name>.yaml under .ops/.")

  return root / ".ops" / source
