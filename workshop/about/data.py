"""Where the plugin keeps the files it writes for itself."""

from pathlib import Path

from ..settings import PLUGIN_ID


def data_dir():
  """The plugin's data folder, as Hermes gives it. Hermes keeps it when the
  plugin is updated or removed, and gives each profile its own. The folder
  comes from Hermes alone, so this raises ImportError outside Hermes; a test
  gives a folder of its own in its place.

    data_dir()  ->  Path("/home/someone/.hermes/plugin-data/creature-workshop")
  """

  from plugins.plugin_storage import plugin_data_dir

  return Path(plugin_data_dir(PLUGIN_ID))
