"""The backend the Desktop pane reads, mounted at /api/plugins/creature-workshop/.

Hermes imports this file by its path and mounts its `router`, which holds
every route the modules under workshop/routes/ register with
workshop.api.register: one module for each topic, named as the client's
modules under desktop/src/client/ are. The routes live in the plugin's own
package and not beside this file because Hermes loads every plugin's
backend into one process, where a second plugin's top-level `dashboard`
package would take the name.

Hermes imports this file by its path, not as part of a package, so the
plugin's root is not on sys.path when the file runs; it is put there before
the routes, which import the plugin's own package, are loaded.
"""

import sys
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
if str(PLUGIN_ROOT) not in sys.path:
  sys.path.insert(0, str(PLUGIN_ROOT))

from workshop.routes import router
