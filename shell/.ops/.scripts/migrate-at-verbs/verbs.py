"""Which structs verbs the migration rewrites, and which files it reads.

A value verb answers through the variable its caller names first. The verbs
below are the ones that do not: a predicate answers with its exit status, an
output verb prints for a person, and a side-effect verb runs a command or
binds variables. The migration leaves calls of those three kinds alone.
"""

import os
import re

PREDICATES = frozenset({"defined", "empty", "is_true", "is_false", "is_zero", "option_is", "is_valid", "validate"})

OUTPUT_VERBS = frozenset({"println"})

SIDE_EFFECT_VERBS = frozenset({"let", "unlet", "foreach", "foreachi", "load_type", "load_types", "enum", "apply"})

SHELL_DIRECTORIES = ("lib", "cli", "actions", "interpreter", ".scripts", "test", "hooks", "shell", "src", "scripts")

SKIPPED_DIRECTORIES = frozenset({".git", "node_modules", ".ops", ".scan", ".logs"})

STRUCTS_LIBRARY = "lib/structs"

VERB_DEFINITION = re.compile(r"^@([a-z_]+)\(\)", re.M)


def value_verbs(shellops_root):
  """The names of the verbs that answer through a variable, read from the structs library under shellops_root."""

  return defined_verbs(shellops_root) - PREDICATES - OUTPUT_VERBS - SIDE_EFFECT_VERBS


def defined_verbs(shellops_root):
  """Every @verb the structs library defines, by name without the @."""

  library = os.path.join(shellops_root, STRUCTS_LIBRARY)
  names = set()
  for entry in os.listdir(library):
    if entry.endswith(".sh"):
      with open(os.path.join(library, entry)) as source:
        names.update(VERB_DEFINITION.findall(source.read()))

  return names


def shell_files(root):
  """Every shell source under root's shell directories: .sh, .bash and .bats files, scripts with a shell shebang, and .envrc."""

  for directory in SHELL_DIRECTORIES:
    yield from shell_files_under(root, os.path.join(root, directory))

  envrc = os.path.join(root, ".envrc")
  if os.path.isfile(envrc):
    yield envrc


def shell_files_under(root, directory):
  """The shell sources under one directory, leaving out vendored trees and the bats libraries under test/lib."""

  if not os.path.isdir(directory):
    return

  for path, subdirectories, files in os.walk(directory):
    subdirectories[:] = [name for name in subdirectories if keeps_walking(root, path, name)]
    for name in files:
      full = os.path.join(path, name)
      if is_shell_source(full):
        yield full


def keeps_walking(root, path, name):
  """Whether a subdirectory is part of the project's own shell: not a vendored tree, and not test/lib."""

  if name in SKIPPED_DIRECTORIES:
    return False

  return not (name == "lib" and path == os.path.join(root, "test"))


def is_shell_source(path):
  """Whether a file is shell: by its extension, or by a shebang that names a shell when it has no extension."""

  if path.endswith((".sh", ".bats", ".bash")):
    return True

  if "." in os.path.basename(path):
    return False

  return has_shell_shebang(path)


def has_shell_shebang(path):
  """Whether the file's first line is a shebang that runs a shell."""

  try:
    with open(path, "rb") as source:
      first_line = source.read(64).split(b"\n")[0]
  except OSError:
    return False

  return first_line.startswith(b"#!") and b"sh" in first_line


def in_structs_library(root, path):
  """Whether a file is the structs library itself, which is migrated by hand; its lint checks are callers like any other."""

  relative = os.path.relpath(path, root)
  return relative.startswith(STRUCTS_LIBRARY + "/") and not relative.startswith(STRUCTS_LIBRARY + "/lint/")
