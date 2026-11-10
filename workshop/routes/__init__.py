"""The backend's routes, one module for each topic, the same topics and
module names as the client's modules under desktop/src/client/: about.py,
what the plugin is; project.py, the shellops project a folder belongs to;
repos.py, the git repositories a folder holds; and store.py, the stores the
inspector reads and writes data through.

Importing this package registers every route in workshop.api, and
dashboard/plugin_api.py mounts the `router` it hands on.
"""

from workshop.api import router
from workshop.routes import about, project, repos, store
