# core/shells/bash — agent guide

Read the root `AGENTS.md` first; this file adds the internals of the loader area.

## File map

| File | Purpose |
|---|---|
| `.bashrc` | Loader. Sourced by `~/.bash_profile` (machine file). Times its own startup. |
| `.bash_profile` | Reference login-shell profile (repo copy; the live one is `~/.bash_profile`). |
| `functions/checks.bash` | `checks` — system info dashboard (OS, CPU, docker, net). |
| `functions/colors.bash` | Color helper functions (`red`, `cyan`, `nocolor`, ...) used by checks. |
| `functions/crlf_to_lf.bash` | CRLF→LF converter helper. |
| `functions/shfmt.bash`, `yamlfmt.bash`, `hadolint.bash`, `shellcheck.bash` | Wrappers that run the respective linters via docker/binary. |
| `functions/myshell.bash` | The `myshell` manager: menu + list. See below. |
| `aliases/.aliases` | Tracked aliases (facilities, git, terraform, bw, docker modules, john, utils, yt-dlp). |
| `aliases/*.sh` | Machine-local, git-ignored. Never add shared aliases here. |
| `profiles/.*` | 9 dot-file profiles, each with an explicit loader block in `.bashrc`. |
| `jobs/public_ip.bash` | Backgrounded at shell start by `.bashrc`. |


## myshell.bash internals

- Dispatch: `myshell` → `do_menu`; `myshell list` → `do_cmds_list`. Nothing else (owner
  decision — do not extend the CLI).
- `do_menu`: numbered menu, options 1-4 → `do_status`, `do_manage_modules`,
  `do_manage_profiles`, `do_cmds_list`; `q` quits. `read -r || return` guards EOF.
- `do_manage_modules` / `do_manage_profiles`: arrow-key menus. **Redraw invariant:** each
  frame prints exactly `${#names[@]} + 5` lines and the redraw does `\033[<lines>A\033[J`.
  If you add or remove a printed line inside the loop you MUST update the `lines`
  variable, or the screen corrupts. First frame skips the cursor-up (`first` flag).
- Key handling uses `IFS= read -rsn1` (silent, no stty juggling). ESC sequences: read 2
  more bytes with `-t 0.05`; bare ESC returns to menu. Enter/T toggle, E enable,
  D disable, Q back.
- Categories with subdirectories toggle every child module (`_cat_enable`/`_cat_disable`);
  flat modules (`bw`, `yt-dlp` — scripts directly in the category dir) are tracked by
  their own directory name.
- `_mod_disable` rewrites the state file via a temp file NEXT TO it (`${_MF}.tmp_$$`) and
  treats `grep -v` exit 1 (no lines left) as success. Keep it that way: writing the temp
  file to `/tmp` and swallowing failures caused silent no-op disables.
- Color helpers `c_green`/`c_red`/... print only `$1`, no newline, no format expansion.
  For colored formatted rows use `printf '\033[0;32m...\033[0m\n' args` directly.
- `do_cmds_list` parses `alias X="... modules/..."` lines from `aliases/.aliases` and
  `aliases/*.sh`, dedupes by name, and skips targets that do not exist on disk.

## Editing rules for this area

- New function file ⇒ three coupled edits: the file, the `.bashrc` if-block, and the
  `func_files` list + `Total: %d/N` counter in `myshell.bash:do_status`.
- `.bashrc` loader blocks reference files that MUST exist — `tests/validate.bash` checks
  every `$project_path/...` it sources.
- Profiles are dot-files; the state file records them WITH the leading dot.
- Anything printed by `_mod_enable`/`_mod_disable` inside the interactive menus must stay
  redirected to `/dev/null` (extra lines break the redraw arithmetic).

## How to verify changes here (copy-paste)

```bash
bash -n core/shells/bash/functions/myshell.bash
shellcheck core/shells/bash/functions/myshell.bash
# menu smoke test with scripted keystrokes (2=modules, arrow down, q back, q quit):
bash -c 'export project_path=$PWD MY_SHELL_ENV_DIR=$(mktemp -d);
  source core/shells/bash/functions/myshell.bash;
  printf "2\n\x1b[Bqq\n" | myshell >/dev/null && echo MENU_OK;
  myshell list | head -5'
bash tests/validate.bash
```
