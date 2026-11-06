# Creature Workshop

A Hermes Agent plugin that puts a project's development lifecycle in front of
the agent and in front of you. The project describes itself once, in its
`.ops/` declaration, through [shellops](https://gitlab.creature-workshop.com/ksoft/shellops);
the plugin reads that declaration, runs the project's own `shell/ops`, and
hands the result to the agent.

## What the agent gets

Four tools, each a thin wrapper of a `shell/ops` command run in the project:

| Tool | What it does |
|---|---|
| `workshop_project` | The declaration files, the release record, the declared tools and which of them are installed right now |
| `workshop_install` | Check the declared tools, or install the missing ones, or the ones named |
| `workshop_test` | The test plan for changed paths, the run of exactly those, or the full suite |
| `workshop_lint` | The house-style lint over paths, or the whole project |

In a session whose directory is a shellops project, the system prompt gets a
short section saying so, with the project's name, its tool count and its
latest release, so the agent reaches for the tools without being told.

## Install

```bash
hermes plugins install creature-workshop
hermes plugins enable creature-workshop
```

Then restart Hermes. Only projects that have
`shell/ops` and `.ops/config/` are recognised; a project gets them with:

```bash
git submodule add https://gitlab.creature-workshop.com/ksoft/shellops.git shell/.ops && shell/.ops/init
```

## Disclosure

- The tools run the project's own `shell/ops` as a subprocess, in the project
  directory, with the project's `.envrc` loaded. Nothing runs outside the
  project.
- `workshop_install` with `check: false` installs tools, which fetches from
  the channel the declaration names: the host's package manager, cargo, npm,
  go, a git repository, Flathub, or an installer script the project ships.
  With `check: true`, the default, nothing is installed.
- The tools read files under the project only.
- No network calls of the plugin's own, no telemetry, no credentials.

## Settings

`ops_timeout_seconds` (default 120): how long one command may run before a
tool reports a timeout instead of waiting.

## Development

```bash
ln -s "$PWD" ~/.hermes/plugins/creature-workshop
hermes plugins enable creature-workshop
hermes plugins doctor . --ci
shell/actions/hermes/check
```

The tracked tree carries source only. Two files are generated and ignored:
`plugin.yaml` and `dashboard/manifest.json`, which
`shell/actions/hermes/manifests` writes from the `.ops/` declaration and the
lock. Write them after a checkout and after an edit:

```bash
shell/actions/hermes/manifests
```

After each merge the pipeline writes them in a scratch branch and deploys
one commit on top of main's to the `built` branch, with
`shell/actions/hermes/deploy`. That commit is what the Hermes catalog pins
and what Hermes installs; main never holds the generated files. The branch
names no rung of shellops' ladder and the release job never moves it; when
promotion carries the build (OPS-1701), the job goes away.

The catalog entry follows: `shell/actions/hermes/catalog-pin` rewrites the
`sha` and `version` of `plugin-catalog/creature-workshop.yaml` on the
`catalog/creature-workshop` branch of the org's fork of hermes-agent and
pushes it as the bot, so the pull request to NousResearch carries the new
pin; the plugin/catalog job runs it after each deploy. Run it by hand with
`--sha` and `--version` to pin another commit, or `--no-push` to look first.

The tools are golden-tested. A case is a directory under
`tests/goldens/cases/` in the shape of a shell-goldens fileset: `name.txt`
and `about.txt` say what the case shows, `calls.txt` and `input/` are the
input (the tool calls, and the project they run in, whose `shell/ops` is a
stub that prints what the case needs), and `expected.txt` is the output, one
block per call with the tool's reply as sorted JSON. The project root is
written as `<root>` and durations as `<ms>`. To add a case, write the first
four and generate the fifth, then read it before you commit it:

```bash
UPDATE_GOLDENS=1 python3 -m unittest tests.test_goldens
```

The scripts under `shell/lint/` are the house rules here: two-space
indentation in Python; one blank line, exactly one, after every multi-line
statement that a statement follows; a doc block at the top of every Python
file; and a JSDoc `/** @file ... */` block at the top of every JavaScript
file. `shell/actions/hermes/check` runs the byte-compile, all four and the tests,
and the plugin/python job runs exactly that.

This repository is itself a shellops project, so the tools have something to
read from its own checkout. The work is tracked in Linear under SHOP.
