# myshell — agent guide (repo root)

myshell is a personal bash framework: a `.bashrc` loader that sources functions, aliases
and profiles from this repo, plus self-contained "modules" (mostly docker compose stacks)
launched through aliases. Everything is bash; there is no build step.

**Before editing under `core/shells/bash/`, read `core/shells/bash/AGENTS.md`.
Before editing under `modules/`, read `modules/AGENTS.md`.**

## How the framework loads (the one chain that explains everything)

```
~/.bash_profile            (machine file, NOT in repo)
  └─ exports project_path=$HOME/Documents/myshell
  └─ sources core/shells/bash/.bashrc, which:
       1. runs core/shells/bash/jobs/public_ip.bash in background
       2. sources core/shells/bash/functions/*.bash   (explicit if-blocks, one per file)
       3. sources EVERY file in core/shells/bash/aliases/   (glob loop)
       4. sources core/shells/bash/profiles/.*         (explicit if-blocks, one per file)
```

Module scripts are executed as `bash <script>` from aliases → they run in a **child
shell** and only see **exported** variables. `$project_path` is exported; never hardcode
`$HOME/Documents/myshell` in a script, always use `$project_path`.

## Repo map

| Path | What it is |
|---|---|
| `core/shells/bash/.bashrc` | The loader. Every new function/profile needs an if-block here. |
| `core/shells/bash/functions/` | 8 sourced function files (`myshell.bash` is the manager UI). |
| `core/shells/bash/aliases/.aliases` | THE tracked alias file. All module aliases live here. |
| `core/shells/bash/aliases/*.sh` | Machine-local aliases. **Git-ignored by design** — never put shared aliases there. |
| `core/shells/bash/profiles/.*` | Dot-file profiles (.appearance, .history, .path, ...). |
| `core/shells/bash/jobs/` | Background jobs run at shell start. |
| `modules/<category>/<module>/` | Self-contained tools: bw, docker, help, john, utils, yt-dlp. |
| `tests/validate.bash` | The validation gate. Run it before calling anything done. |
| `.module_state/` | Machine-local menu state (git-ignored). Bookkeeping only — nothing loads based on it. |

## Golden rules (each one caused a real bug — do not relearn them)

1. **Module aliases go ONLY in `core/shells/bash/aliases/.aliases`.** Every other file in
   `aliases/` is git-ignored (`.gitignore` rule `core/shells/bash/aliases/*` with a single
   `!.aliases` exception). An alias added to `.modules.sh` etc. silently never reaches git.
2. **Every alias that points into `modules/` must reference a file that exists.**
   `myshell list` derives the command list from `.aliases` and hides dead targets, so a
   broken alias becomes invisible instead of failing loudly. `tests/validate.bash` enforces
   this. (Cause: a batch of `modules/k8s` aliases survived the module's deletion.)
3. **Use `docker compose` (plugin), never `docker-compose`.** With the plugin missing the
   CLI fails with the misleading error `unknown shorthand flag: 'd' in -d`. If you see that
   error, the compose plugin is missing — the script is not broken.
4. **The `myshell` user interface is exactly two entry points:** `myshell` (interactive
   menu) and `myshell list`. Do NOT add CLI subcommands; the owner removed them on purpose
   (2026-07-12). New capabilities go into the menu.
5. **The `c_green`/`c_red`/`c_blue`/... helpers in `myshell.bash` print ONLY their first
   argument, with no newline and no printf formatting.** Passing `"%s" "$x"` prints a
   literal `%s`. For formatted or colored lines use `printf` with escape codes directly.
6. **`.module_state/enabled.modules` is bookkeeping, not a gate.** One name per line:
   module directory basenames (`alpine`, `mysql5`), flat modules by their own dir name
   (`bw`, `yt-dlp`), profiles with their leading dot (`.appearance`). Nothing in the
   loader reads it; disabling a module does not remove its command.
7. **`.shellcheckrc` accepts directives only** (`shell=bash`, `external-sources=true`).
   No INI sections, no file excludes — those break every shellcheck run in the repo.
8. **Never edit files under `modules/docker/*/Docker/` that came from upstream images**
   (e.g. `catalina.bash` — 600+ line Tomcat vendor configs). They are container config
   payloads, not framework code.

## Cookbook (follow the recipe exactly; each step lists its coupled edits)

### Add a docker service module
1. `mkdir -p modules/docker/<name>` with `docker-compose.yaml` (copy `modules/docker/alpine/`
   as reference: service with `container_name: <name>`, optional `build:` context `./Docker`).
2. Create `modules/docker/<name>/<name>.bash`:
   ```bash
   #!/bin/bash
   cd "$project_path/modules/docker/<name>" || exit 1
   docker compose up -d --build --force-recreate
   ```
   Optional shell access: `<name>_exec.bash` with `docker exec -it <name> /bin/sh`.
3. Add the alias in `core/shells/bash/aliases/.aliases`, INSIDE the docker-group guard
   block (between `if [ "$docker_groups" = "$docker_str" ]` and its `else`):
   `alias <name>="bash $project_path/modules/docker/<name>/<name>.bash"`
4. Verify: `cd modules/docker/<name> && docker compose config --quiet` then
   `bash tests/validate.bash`.

One-shot tools (run-and-exit, like `k6`) use `docker compose run --rm <service> ...`
instead of `up -d`. See `modules/docker/k6/k6.bash`.

### Add a utility script
1. Create `modules/utils/<topic>/<script>.bash` (use `$project_path`, pass shellcheck).
2. Add alias in `.aliases` under `# Utils`.
3. `bash tests/validate.bash`.

### Add a core function file
1. Create `core/shells/bash/functions/<name>.bash`.
2. Add an if-block in `.bashrc` under `# Load functions` (copy an existing block).
3. **Coupled edit:** add `<name>` to the `func_files` list in
   `core/shells/bash/functions/myshell.bash` (function `do_status`) AND bump the
   `Total: %d/N functions` counter on the next line. Grep first: `grep -n 'func_files=' core/shells/bash/functions/myshell.bash`.
4. `bash tests/validate.bash`.

### Add a profile
1. Create `core/shells/bash/profiles/.<name>` (leading dot).
2. Add an if-block in `.bashrc` under `# Load profiles`.
3. `bash tests/validate.bash`.

## Validation protocol — non-negotiable before "done"

Ground every claim in tool output, not memory. In order:

1. `bash -n <every file you touched>` — syntax.
2. `shellcheck <touched .bash files>` — must be clean (repo `.shellcheckrc` applies).
   Semgrep is available via MCP — scan touched files when you change logic.
3. `bash tests/validate.bash` — the full gate: syntax of all shell files, shellcheck on
   core functions, loader integrity (.bashrc targets exist), alias→script integrity,
   `docker compose config` for every docker module, and a `myshell` smoke test.
4. Quote the actual output in your report. If a check fails, fix and re-run; never report
   a failing state as done.

CI runs the same gate (`.github/workflows/validate.yml`) plus manual docker image builds
(`manual.yml`, `schedule.yml` — do not touch those when doing framework work).

## Do NOT

- Do not resurrect `module_resolver.bash`, `framework_core.bash`, `env_core.bash` or any
  `myshell_mod_*` function — removed on purpose (2026-07-12/13).
- Do not add subcommands to `myshell` (rule 4).
- Do not `git add -f` git-ignored files (machine-local aliases, `.module_state/`).
- Do not delete or stop running containers/services without being asked.
- Do not "fix" `modules/docker/*/Docker/` vendor payloads flagged by linters (rule 8).
- Do not reference `modules/k8s`, `modules/ssh`, `modules/minikube`, `openldap`,
  `passbolt` — deleted; they must not reappear in aliases or docs.

## Commits

Conventional commits: `feat:` / `fix:` / `docs:` / `refactor:` / `chore:`.
All paths through `$project_path`. Run the validation protocol before every commit.
