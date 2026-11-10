"""The environment of every program the plugin starts.

A program the plugin starts inherits a short list of the variables Hermes
runs with: where programs and the user's files are, the locale, the terminal
and the time zone. It inherits nothing else, so a provider key, a token or
one of Hermes's own variables never reaches git or a project's scripts. A
project's .envrc sets what its commands need beyond the list, which is how
SHELLOPS_DIR and PROJ reach shell/ops: a value Hermes was started with
would name another project.

The ops_env_passthrough setting names more variables for the user who needs
them in every command, a proxy for one. It is empty until the user fills it.
"""

import os
import re

from .. import settings

INHERITED_NAMES = frozenset([
  "PATH",
  "HOME",
  "USER",
  "LOGNAME",
  "SHELL",
  "LANG",
  "LANGUAGE",
  "TERM",
  "TMPDIR",
  "TZ",
  "NO_COLOR",
  "XDG_CACHE_HOME",
  "XDG_CONFIG_HOME",
  "XDG_DATA_HOME",
  "XDG_RUNTIME_DIR",
  "XDG_STATE_HOME",
])

LOCALE_PREFIX = "LC_"

VARIABLE_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def child_env():
  """The environment for a program the plugin is about to start: the inherited
  variables of this process, and the ones the ops_env_passthrough setting names."""

  return inherited(os.environ, passthrough_names(settings.value("ops_env_passthrough")))


def inherited(environ, passthrough=frozenset()):
  """The variables of environ that a child process gets: the ones on the list, the
  locale's, and the ones passthrough names.

    inherited({"PATH": "/usr/bin", "LC_ALL": "C", "OPENAI_API_KEY": "sk-1", "HTTPS_PROXY": "http://proxy:3128"},
              {"HTTPS_PROXY"})  ->  {"PATH": "/usr/bin", "LC_ALL": "C", "HTTPS_PROXY": "http://proxy:3128"}
  """

  return {name: value for name, value in environ.items() if is_inherited(name) or name in passthrough}


def is_inherited(name):
  """Whether every child process gets the variable: it is on the list, or it is one of the locale's."""

  return name in INHERITED_NAMES or name.startswith(LOCALE_PREFIX)


def passthrough_names(setting):
  """The variable names in the ops_env_passthrough setting, as a set. An entry that
  is not a variable name is left out, and so is everything when the setting is not a list.

    passthrough_names(["HTTPS_PROXY", "not a name", 7])  ->  frozenset({"HTTPS_PROXY"})
  """

  if not isinstance(setting, list):
    return frozenset()

  return frozenset(entry for entry in setting if isinstance(entry, str) and VARIABLE_NAME.fullmatch(entry))
