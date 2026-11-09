# Creature Workshop

A Hermes Agent plugin that puts a project's development lifecycle in front of
the agent and in front of you. The project describes itself once, in its
`.ops/` declaration, through [shellops](https://gitlab.creature-workshop.com/ksoft/shellops);
the plugin reads that declaration, runs the project's own `shell/ops`, and
shows the result in a Desktop pane.

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

And one hook, on every terminal command. When the command runs a program the
project declares in `.ops/config/tools.yaml` and `install --check` reports
missing, the hook blocks the command before it runs and tells the agent the
tool, its declared version and channel, and the `workshop_install` call that
installs it, so the agent installs and retries instead of failing on a
command that was never going to work. A program the project does not declare
passes, as does every command outside a project. The check behind the hook
is cached for `pane_refresh_seconds` and forgotten after an install.

## What you get

A Desktop pane, **Workshop**, docked on the right. Its footer says which
version of the plugin you are on (`release.latest` of the plugin's own
`.ops/lock`) and which branch the checkout Hermes loaded it from is on. The
rest of the pane is being rebuilt around the project's plan, one part at a
time, and the parts arrive in later releases.

## Install

```bash
hermes plugins install creature-workshop
hermes plugins enable creature-workshop
```

Then restart Hermes. The pane needs Hermes Desktop. Only projects that have
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
- The hook on the terminal reads the command's text to find the programs it
  runs and runs `shell/ops install --check` to know which are missing; it
  never runs the command itself, and it blocks nothing outside a project.
- The backend in `dashboard/plugin_api.py` runs `shell/ops install --check`
  for the pane on a timer. It reads files under the project only. What it
  answers with is the models under `workshop/models/`, one module per concept.
- Every `shell/ops` run is logged under the `creature-workshop` logger,
  which Hermes writes to `~/.hermes/logs/`: successes at INFO in agent.log,
  failures at WARNING with their stderr in errors.log too, so `hermes logs`
  shows what the plugin ran. The pane writes a render error to the console.
- No network calls of the plugin's own, no telemetry, no credentials.

## Settings

Both are set under Settings → Plugins in Hermes Desktop, or under
`plugins.entries.creature-workshop.settings` in Hermes's configuration.

- `ops_timeout_seconds` (default 120): how long one command may run before a
  tool reports a timeout instead of waiting. A tool call's own
  `timeout_seconds` overrides it for that call.
- `pane_refresh_seconds` (default 20): how often the pane re-runs
  `install --check`. A save takes effect at once; the pane reloads on it.

## Development

The layout is the one Hermes expects. The root is the Python side:
`__init__.py` is the entry point Hermes imports, and `workshop/` is its
package. `dashboard/plugin_api.py` is the backend, at the path the dashboard
manifest names. Everything JavaScript is under `desktop/`, which Hermes
Desktop loads, with the source under `desktop/src/`.

`.ops/config/` is how the project describes itself: the YAML files at its
top are the declaration, and each folder under it is one tool's own
configuration, named after the tool, which shellops never reads: `eslint/`,
`playwright/`, `uv/` and `gitlab/`. What a tool rebuilds from its
configuration goes under `.ops/cache/<tool>/`, which is ignored. The two
files that stay at the root do so because their tools insist: `package.json`
with its lock, since Node resolves imports by walking up to `node_modules`,
and `.gitlab-ci.yml`, two lines that include the real pipeline.

```bash
ln -s "$PWD" ~/.hermes/plugins/creature-workshop
ln -s "$PWD/desktop" ~/.hermes/desktop-plugins/creature-workshop
hermes plugins enable creature-workshop
hermes plugins doctor . --ci
. ./.envrc
uv sync
uv run shell/actions/hermes/check
```

`.ops/config/uv/pyproject.toml` lists, as its dev group, what the checks
need and the plugin does not: PyYAML to read the declaration outside Hermes,
FastAPI for the backend, and coverage; `uv.lock` beside it pins them, and
`uv sync` installs them into `.ops/cache/venv/`. The project's `.envrc`
names both paths to uv, so load it first, which direnv does. `check` runs
the tests under coverage and ends with the report, file by file with the
lines the tests miss.

The tracked tree carries source only. Three files are generated and ignored:
`plugin.yaml` and `dashboard/manifest.json`, which
`shell/actions/hermes/manifests` writes from the `.ops/` declaration and the
lock, and `desktop/plugin.js`, the file Desktop loads, which
`shell/actions/hermes/build` bundles with esbuild from the JSX under
`desktop/src/`; esbuild is declared on the npm channel in
`.ops/config/tools.yaml`, and `shell/ops install esbuild` fetches it. Write
them after a checkout and after an edit:

```bash
shell/actions/hermes/manifests && shell/actions/hermes/build
```

While working on the pane, `shell/actions/hermes/build --watch` rewrites
the output on every change, and Desktop reloads it.

The pipeline in `.ops/config/gitlab/ci.yml`, which the `.gitlab-ci.yml` at
the root includes, is the creatures catalog's `forge`,
`linear` and `agents` components, which keep the merge request, its issues
and its hat label in step, plus one job per action under
`shell/actions/hermes/`: `plugin/python` runs `check`, `plugin/manifests`
and `plugin/desktop` prove the two generators still run, `plugin/javascript`
runs ESLint, the tests of its two house rules and the browser tests,
`plugin/deploy`, after each merge, builds the
generated files in a scratch branch and deploys one commit on top of main's
to the `built` branch, and `plugin/catalog` then moves the catalog's pin to
that commit. That commit is what the Hermes catalog pins and what
Hermes installs; main never holds the generated files.

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

The pane is tested in a browser. `desktop/src/pane/pane.ct.jsx` mounts the
pane through Playwright's component runner and reads it by role and by
text, the way a user would. `pnpm install` fetches the runner
and React (pnpm is declared on the npm channel, and `package.json` names it
for corepack), `pnpm exec playwright install chromium` the browser, and
then:

```bash
pnpm run test:pane
```

The runner's configuration is `.ops/config/playwright/`, with the page each
test mounts into under `template/` beside it, and what Playwright builds
goes under `.ops/cache/playwright/`.

In CI the same tests run on Playwright's own image, so the browser is
there, and pnpm is installed with npm at the version `package.json` names,
because that image's corepack cannot verify the registry's current signing
key.

The house rules for Python and YAML are the scripts under `shell/lint/`:
two-space indentation in Python; one blank line, exactly one, after every
multi-line statement that a statement follows; a doc block at the top of
every Python file, with exactly one blank line after it; a module's constants before its first function, and no
banner comment, since either is the sign that a file should split; and no
comments in YAML, where what a comment would say belongs with the thing it
describes. `shell/actions/hermes/check` runs the byte-compile, all five and
the tests, and the plugin/python job runs exactly that.

The house rules for JavaScript are ESLint, configured in
`.ops/config/eslint/eslint.config.js`:
ESLint's and React's recommended rules; a JSDoc `/** @file ... */` block at
the top of every file, with exactly one blank line after it; a JSDoc block on every top-level declaration,
exported or not, with a description and one line per parameter; one React
component per file, in a file of the component's name; a doc block above
every `useEffect`, saying what the effect does and when it runs, because an
effect is a side effect at the boundary of the UI with no name of its own;
no other comment inside a function body, because a step that needs one is
its own function; and a `workshop-` class on every `div` and `span`, saying
what the box is, since a semantic element or a role already says it; a
module's constants before its first function, and no banner comment, the two
signs that a file should split. The
browser tests get Playwright's own rules on top, with its locator rules on,
and no test ids anywhere: a test finds the page by role and by text, the
way a user does. The last eight are the plugin under
`shell/lint/eslint/`, tested with
ESLint's RuleTester over the fixtures under `tests/fixtures/`. The one way
to make an exception is ESLint's own `eslint-disable-next-line` comment,
with the reason after `--`.

```bash
pnpm run lint && pnpm run test:lint
```

This repository is itself a shellops project, so the pane has something to
show from its own checkout. The work is tracked in Linear under SHOP.
