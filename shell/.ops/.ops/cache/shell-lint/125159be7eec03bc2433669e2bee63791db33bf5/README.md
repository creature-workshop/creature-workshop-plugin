# shell-lint

The house-style lint for shell, awk, jq, markdown and yaml sources: the
check registry, the discovery of what a run reads, the runner, and every
check. It is a shellops consumer: `shell/lint` holds the engine and the
checks, and `cli/lint` runs them over a repository.

    SHELLOPS_DIR=<shellops> SHELL_SCAN_DIR=<shell-scan> \
      PROJ=<the repository> cli/lint [--list] [--check <name>]... [--added-only | --added-since <ref>] [files...]

`cli/lint --help` says what a run does and what `lint.json` may set. Each
variable is the root of that repository's copy; one left unset falls back
to the copy vendored under `shell/`. The checks come from three places, in
this order, and a name keeps its first plugin: `shell/lint` here, shellops'
`lib`, whose modules ship the checks that police them, and the directories
the repository's `lint.json` lists under `checks`.

A check is a folder under `shell/lint/checks/<subject>/`, one per check,
named for it, under the subject it reads: `adrs` for decision records,
`awk` for awk programs, `shell` for shell sources, `templates` for CI
component templates. The folder holds the plugin file `<name>.check.op.sh`,
whose roles `shell/lint/registry.sh` describes, an `api.sh` whose run
function the plugin calls, and the detector awk the run function loads.
Adding a check is adding a folder. What the checks of a subject share is a
module in the subject's folder, with the fixtures its tests read:
`adrs/api.sh`, `form.sh` and `fixtures.sh`, `shell/comments.sh` for the
ten doc-block checks, and `templates/api.sh`. The awk libraries a detector
loads sit
under `shell/lint/lib/`, the scanner among them coming from
[shell-scan](../shell-scan), so every reader of a shell file draws the same
boundaries.

The tests under `test/` are one suite per check, `check.<name>.bats`, and
one per part of the engine, `lint.<part>.bats`.

`shell/.ops` and `shell/.scan` vendor shellops and shell-scan for this
repository's own tests and lint, and for nothing else. A repository takes
this lint at a pin.

The work is tracked in Linear on the SILT project, from STRATA-231.

shell-lint is licensed under the [Apache License, Version 2.0](LICENSE).
