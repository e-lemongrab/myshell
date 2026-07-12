# modules/ — agent guide

Read the root `AGENTS.md` first. A module is only reachable through an alias in
`core/shells/bash/aliases/.aliases` — creating files here does nothing until that alias
exists, and an alias without its target file is invisible dead weight (`myshell list`
hides it; `tests/validate.bash` fails on it).

## Categories (current, complete)

| Category | Kind | Contents |
|---|---|---|
| `bw/` | flat (scripts at top level) | Bitwarden CLI helpers (`bw_create`, `bw_push`, `bw_clone`). |
| `docker/` | one dir per service | 18 compose stacks: alpine, apache, cockroach, cockroach-insecure, jira-software, k6, liferay-7.2.1-ga2, liferay-7.3.5-ga6, maven, mongodb, mysql5, mysql8, nexus, nginx, nodejs, rainloop, syslog, tomcat9. Plus 3 special dirs (see below). |
| `help/` | one dir per topic | Cheatsheet printers (`help_docker`, `help_az`, ...). Plain bash, no deps. |
| `john/` | one dir per attack | John the Ripper recipes. Aliases only defined when `john` binary exists. |
| `utils/` | one dir per topic | ssl checks, cert helpers, aws, disk format, etc. |
| `yt-dlp/` | flat | `download` alias → `yt-dlp.bash`. |

Deleted, must not reappear: `k8s/`, `ssh/`, `minikube/`, `docker/openldap`, `docker/passbolt`.

## Special docker dirs (no compose service)

- `docker/dock/` — loose docker utility scripts. Only `dockrm.bash` has an alias
  (`dockrm`); `dockpush.bash`, `dockpush_k8s.bash`, `dock_ports_bind.bash` are run by
  hand. `dockrm.bash` sources `$mod_colors` (exported in `.aliases`).
- `docker/httpd/`, `docker/vtiger/` — Dockerfile + payload only, no launcher script and
  no alias. Do not invent launchers for them unless asked.

## Docker module anatomy (the pattern every compose stack follows)

```
modules/docker/<name>/
├── docker-compose.yaml    # service, container_name: <name>, often build: ./Docker
├── <name>.bash            # cd "$project_path/modules/docker/<name>" && docker compose up -d --build --force-recreate
├── <name>_exec.bash       # optional: docker exec -it <name> /bin/sh (or bash)
├── Docker/                # build context: dockerfile + payload. Vendor files live here — do not lint/fix them.
└── configs/ README.md     # optional
```

The exception: `k6` is a one-shot job, not a service. Its `k6.bash` asks which script
under `scripts/` to run, then `docker compose run --rm k6 run /mnt/local/scripts/<x>/<x>.js`.
Never convert it to `up -d`.

Aliases for docker modules sit INSIDE the docker-group guard in `.aliases`
(`if [ "$docker_groups" = "$docker_str" ]` ... `else` warning `fi`). Aliases for john sit
inside the john guard. Everything else is unguarded.

## Rules

- Scripts run in a child bash: only exported vars exist. Use `$project_path`, quote it:
  `cd "$project_path/modules/..." || exit 1`.
- `docker compose` (plugin syntax), never `docker-compose`.
- Compose files must pass `docker compose config --quiet` from inside the module dir —
  the validator runs exactly that for every `modules/docker/*/docker-compose.y*ml`.
- Machine-generated data dirs (mysql-data, logs, liferay_data, ...) are git-ignored; do
  not commit them and do not add code that writes elsewhere in the repo.
- Removing a module = remove its directory AND its alias line(s) in `.aliases`, then run
  `bash tests/validate.bash` (it fails on orphan aliases).

## How to verify changes here (copy-paste)

```bash
bash -n modules/docker/<name>/<name>.bash
shellcheck modules/docker/<name>/<name>.bash        # SC2154 for project_path is expected noise
cd modules/docker/<name> && docker compose config --quiet && cd -
bash tests/validate.bash
```
Do not `docker compose up` anything as a test unless the task asks you to run it.
