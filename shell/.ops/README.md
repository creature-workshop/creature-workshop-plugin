# Shellops

Shellops runs a software project's development lifecycle from the shell:
installing its tools, linting, testing, versioning, releasing, and talking to
the forge that hosts its code. A project vendors it as a git submodule, and
the same commands run on a developer's machine and in CI.

- Declarative tool installation from a layered, versioned lockfile
- Test selection, in shadow: each code review is labelled with the areas its
  diff touches, and the suites those areas map to run and are recorded beside
  the full suite, which still runs on every review
- End-to-end release automation: version planning, tagging, forge releases, Homebrew
- One forge API over GitLab and Forgejo, with GitHub for releases, uploads
  and pipeline runs, and Linear integration
- Structured data in POSIX sh via the structs `@`-API, with a lint suite that enforces the house style
- A Rust engine that compiles `.ops` sources to POSIX sh

## Usage

The first command in a new project adds shellops as a submodule and
bootstraps it:

```bash
git submodule add https://gitlab.creature-workshop.com/ksoft/shellops.git shell/.ops && shell/.ops/init
```

On a fresh clone of a project that already has it, the boot `init` wrote
fetches the submodule and runs `init` again:

```bash
./.ops/boot
```

`init` is idempotent: it sets up the project's `.envrc` and `.gitignore`,
copies the `ops` and `action` dispatchers to `shell/`, writes `.ops/boot`
(the seeds the project's Strata LIDs are drawn from and the hand-off back
to `init`, rewritten only when its shape changes; ADR 000047), and installs the tools
the project's tools declaration and shellops' own name, so a project with no
declaration still gets shellops' toolchain (`--no-install` skips installation;
`--install tool...` narrows it).

Load the `.envrc` that `init` writes before running anything else, with
`direnv allow` or `source .envrc`. It sets `PROJ` to the project root;
without it the dispatchers act on the shellops checkout instead of the
project.

```bash
shell/ops install --check
shell/ops lint --list
```

`install --check` shows which locked tools are installed, and `lint --list`
names the house-style checks `ops lint` runs. Versioning, release and test
selection read the project's declaration, `.ops/config/manifest.yaml`,
which `schema/manifest.schema.json` defines, and the release record in
`.ops/lock`.

## Dispatchers

- `ops <cmd>` runs `cli/<cmd>`, a flat, one-level resolution. When shellops
  has no `cli/<cmd>`, it runs the `cli/<cmd>` of the first tool the lock
  pins that carries one, so `ops docs` is shell-docs' command and needs no
  wrapper here. With no arguments it lists every available command, the
  pinned tools' with their tool.
- `action <path...>` resolves recursively under `actions/`: argv tokens are
  consumed as directory segments until an executable is found, so
  `action git tags prune` runs `actions/git/tags/prune`.

## Commands

| Group | Commands |
|---|---|
| Tooling | `install`, `fingerprint-env` (one line per job input the run declares: unset, empty, or set, with a digest for a secret) |
| Compilation & reference | `compile` (writes `.ops/__compiled__`, the compiled tree of the project's `lib/`, by hand; `.envrc` derives it on its own when the sources change), `docs lib` (shell-docs' command, run from the lock by the dispatcher; writes `.ops/docs`, one page per library module and an index; the trunk's pipeline renders and keeps them after every landing, at [the reference](https://gitlab.creature-workshop.com/ksoft/shellops/-/jobs/artifacts/main/browse/.ops/docs?job=shellops%2Fdocs%2Freference)) |
| Versioning & release | `git-bump`, `plan-version`, `promote` (opens the merge request that moves the version one rung up the release ladder), `sync-manifest`, `publish-release`, `git-commit`, `git-config` |
| Review hygiene | `pr-hygiene`, `apply-labels`, `request-review` |
| Runner hygiene | `stale-guard` (watches the pipeline a job belongs to and cancels it once nothing will merge its commit) |
| Test selection | `test` (context-aware run, `all`/`area`/`suite`/`files`/`plan`/`scorecard`/`trace`) |
| Lint suite | `lint` (every registered house-style check; `--list` names them), `shellcheck` |
| Profiling | `profile` (what one command costs, by the profiler named; `--list` names them; `forks` counts forks and program starts under strace) |
| Infrastructure | `infra` (plans `.ops/infra`, the project's GitLab settings and pipeline schedules as Terraform, against the state GitLab manages for the project; `--apply` applies it) |

`actions/` holds what CI jobs run, and `shell/action` with no arguments lists
all of it:

- Release: `release`, `cargo publish`/`sync-version`, `homebrew update-tap`,
  `govern suggest-version`, `github release-catchup`
- Git and forge: `git auth`/`config`/`credential`/`sign`/`tags`/`version-guard`, and
  `forge` for label sync, artifacts, packages and a run's report
- Tracker: `linear sync-refs`, `close-mentioned-issues` and `close-merged-issues`
- Build and test: `rust build-release`/`test`/`lint`/`coverage`/`fuzz`/`security`,
  `node install`/`lint`/`build`, `deployment preview`/`production`, and
  `testing` for the selection records and the scorecard
- Agents: `agents`, `claude-cli`, `cursor` and `cursor-cli` run and manage
  headless coding agents
- Rendering: `render` and `likec4 export`

## Structure

```
init                # Consumer bootstrap (idempotent, no prerequisites)
ops                 # CLI dispatcher (copied to shell/ops by init)
action              # Action dispatcher (copied to shell/action by init)
cli/                # Subcommands (standalone executables)
actions/            # CI actions, resolved recursively by `action`
lib/                # Sourceable libraries: a module's api.sh, its concerns beside it, and its plugins (*.op.sh)
plugins/
  tools/            # Built-in .installer.sh/.uninstaller.sh for the script channel
builtins/           # Global @type declarations for the .op.sh interpreter
interpreter/        # Bash .op.sh interpreter + registry emitter
engine/             # Rust workspace: compiles .ops sources to POSIX sh
schema/             # JSON schemas (the tools declaration, manifest, testmap, labels, releases, test records)
test/               # bats suite, e2e smoke, fixtures
.scripts/           # Self-hosting wrappers so shellops lints itself
.gitlab-ci/         # shellops' own pipeline
docs/
  decisions/        # ADRs, one decision each
.ops/boot           # This checkout's boot: its seeds, and the hand-off to `cli/install`
.ops/infra          # The merge gate and pipeline schedules as Terraform, applied by `ops infra`; hand-written and tracked
```

Consumer project layout:

```
project/
  .envrc                      # export PROJ; source shell/.ops/.envrc (written by init)
  .ops/config/manifest.yaml   # the project's declaration: identity, naming, labels, testing (ADR 000049)
  .ops/config/ecosystems.yaml # the ecosystems the adaptors read
  .ops/config/imports.yaml    # what the project sources at run time: git repositories, each at a commit (ADR 000050)
  .ops/config/tools.yaml      # the tools declaration: what the project runs, by channel; a git channel for dev-time trees
  .ops/config/lint.yaml       # the lint declaration
  .ops/lock                   # what the resolver derives from the declarations: the seeds, the release record, the git graph, the tools by channel; written by ops install and the release job, tracked (ADR 000049)
  testmap.json                # optional test-impact map (or manifest .testing)
  .ops/boot                   # the hand-off to init, the same in every repository; written by init, tracked
  .ops/infra/                 # the project's infrastructure as Terraform, planned and applied by `ops infra`; hand-written, tracked
  .ops/cache/env.sh           # PATH activation, generated by `ops install`; gitignored
  .ops/cache/pins.sh          # where each git dependency's tree is, relative to the file, derived from the lock by .envrc; gitignored
  .ops/__compiled__/          # the compiled tree of the project's own lib/, derived by the first shell to need it (ADR 000047); untracked
  .ops/docs/             # one page per module of the project's own lib/, written by `ops docs` through shell-docs; untracked
  .ops/testing-metrics/       # one record per `ops test` run; untracked
  shell/
    ops                       # dispatcher (copied from .ops/)
    action                    # dispatcher (copied from .ops/)
    .ops/                     # submodule
    scripts/                  # project .installer.sh/.uninstaller.sh
    channels/                 # project @channel.<name> plugins (optional)
    tools/                    # project @tool.<name> plugins (optional)
    <module>/                 # project modules of its own, a kind or a library, as lib/ lays them out (ADR 000045)
```

A project whose shell lives under `scripts/` or `src/` instead keeps its
modules there, and the lint reads each of the three homes as it reads
`lib/`; `library_roots` in the lint declaration names a different list (ADR 000045).

`init` adds `/.ops/cache`, `/.ops/__compiled__*` and `/.ops/docs` to `.gitignore`; list
`/.ops/testing-metrics/` there too.

## Tool installation

`ops install` reads the tools declaration, `.ops/config/tools.yaml`, or the
`ops.lock` at the project root while the project has not converted (ADR
000049), layered on top of shellops' own; project entries win where both
name the same tool. Channels are top-level keys — `system`, `script` (aliased
`local`), `cargo-install`, `cargo-binstall`, `go-install`, `npm`, `flatpak`,
`git` — and each tool is an object with at least a `version`:

```json
{
  "cargo-binstall": {
    "tokei": { "version": "14.0.0", "args": "--locked --force" }
  },
  "go-install": {
    "govulncheck": { "version": "1.1.4", "pkg": "golang.org/x/vuln/cmd/govulncheck" }
  },
  "npm": {
    "prettier": { "version": "3.6.2", "bin": "bin/prettier.cjs" }
  },
  "script": {
    "zig": { "version": "0.16.0" }
  }
}
```

The `script` channel provisions a tool through its `<tool>.tool.op.sh`
plugin when one answers `@install`: one shellops ships under `lib/`, beside
the module that installs it, or one the project keeps under
`$TOOLS_PLUGINS_DIR` (default `$PROJ/shell/tools`); `lib/toolchain/tool.sh`
says what the roles are. Otherwise it runs the tool's `<tool>.installer.sh`
/ `<tool>.uninstaller.sh` pair, searching shellops' `plugins/tools/` first
and then `$TOOLS_SCRIPTS_DIR` (default `$PROJ/shell/scripts`), with the
project's winning. Project-specific channels live beside them in
`shell/channels/`.
The `flatpak` channel installs a Flathub application, named by its
application id, into the user's own Flatpak installation, and puts the
installation's exports directory on PATH so the application runs by its id.
Flathub serves one current build, so the install checks the version it ended
at against the pin and fails naming the one served; an entry's `commit` holds
an older build. The channel depends on `flatpak` from the `system` channel.

`ops install tool@variant` selects a non-default variant (e.g.
`rustup@nightly`).

Installed tools land on the PATH through `$PROJ/.ops/cache/env.sh`, which
`ops install` writes and the consumer `.envrc` sources.

## CI

A project's pipelines come from
[creatures](https://gitlab.creature-workshop.com/ksoft/creatures), a catalog
of GitLab CI components: the project includes the packages it wants, and each
job runs a shellops command or action against the vendored submodule.
`.gitlab-ci/` here is shellops' own pipeline.

The trunk validates nothing (ADR.3@global, ADR 000044): a change is
validated by its landing run against the trunk's head before it merges, so
main promises green on the suites each change touched. The full suite is the
alpha tier's condition, earned off the trunk by certification, and the job
after a landing does only cheap things: check C, tested is merged, and the
dev tag on the merge commit.

`apply-labels` maps a code review's diff to `area/*` labels, and `ops test`
reads them back and runs the impacted suites. A repo without an area tree
runs the full suite, never none. On shellops, selection is in shadow: the
landing run still runs the full suite beside it, and `ops test scorecard`
reports how the mapping and the recorded runs are holding up.

## Conventions

Production shell targets POSIX sh — no `local`, `[[ ]]`, arrays, `declare`,
process substitution, or the `function` keyword — with structured data going
through the structs `@`-API (`lib/structs/api.sh`). `ops shellcheck` holds
the first and `ops lint` the rest, in CI and in the lefthook pre-commit
hooks; shellops lints itself through the wrappers in `.scripts/`.

A library function's name carries its module path, `forge__selected` in
`lib/forge`, with a leading `__` when only its module calls it.

Docs are heredocs, and the label a doc opens on says what it documents:
`MODULE` for a library file consumers import and `FRAGMENT` for one only its
module does, `PUB_FUN` for a function in a module's public surface and `FUN`
for any other, and `HELP` for an entrypoint's usage. A constant or variable
at the root of a file takes `CONST` or `VAR`, as a heredoc or a one-line
`# CONST:` comment, with `PUB_` in front when a library exports the name. A
function body carries no comments; what one would explain belongs in the
function's doc.

```sh
: <<'PUB_FUN'
Prints the name of the forge the run is on.
PUB_FUN
forge__selected() {
```

A lint check is a plugin: a file named `<name>.check.op.sh` under `lib/`,
next to the code it checks, holding one `@check.<name>()` function with five
roles -- `@run <opts> <files...>`, `@languages`, `@scopes`, `@summary` and
`@hint` (shell-lint's `shell/lint/registry.sh` explains each). `@run` prints
findings only; the engine follows them with the summary and hint, and
`ops lint --explain <name>` prints both on their own. A shell check's
detection is usually an awk program over the scanner in shell-scan's tree,
`$SHELL_SCAN_DIR/shell/scan/scan.awk`. Every such file is found and loaded
automatically; to add a check, add the file. The lint itself is shell-lint,
pinned in the git channel of `.ops/config/tools.yaml` and reached through
`SHELL_LINT_DIR`; `ops lint` runs its `cli/lint`, and the pin moves in a
merge request of its own. The lint declaration, `.ops/config/lint.yaml`,
sets the indent width, the test directory names, the directories no check
looks in, the checks held to new lines only while the code is brought up to
them, and which yaml files are CI component templates.

## Environment

- `PROJ` — project root (set by the consumer `.envrc` or CI)
- `SHELLOPS_DIR` — path to the shellops checkout (set by `.envrc`)
- `TOOLS_SCRIPTS_DIR` — script-channel installer search path (default `$PROJ/shell/scripts`)
- `TOOLS_PLUGINS_DIR` — the project's own tool plugins (default `$PROJ/shell/tools`)
- `SHELLOPS_FORGE` — forge backend for API operations: `gitlab` (default) or `forgejo`
- `FORGE_ADMIN_TOKEN` — token for release creation and other admin forge operations
- `FORGEJO_TOKEN`, `GITHUB_TOKEN` — tokens for Forgejo and GitHub when a run on another forge asks them by name

## Licence

Shellops is licensed under the [Apache License, Version 2.0](LICENSE).
