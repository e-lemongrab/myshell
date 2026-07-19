#!/bin/bash
# myshell validation gate — run from anywhere: bash tests/validate.bash
# Checks: shell syntax, shellcheck, .bashrc loader integrity, alias->module integrity,
# myshell func_files consistency, docker compose configs, myshell smoke test,
# shebang on extensionless dot-files, hardcoded paths, anti-patterns.
set -u
cd "$(dirname "$0")/.." || exit 1
root=$PWD
fails=0
fail() { printf 'FAIL: %s\n' "$1"; fails=$((fails + 1)); }

# ── 1. bash -n on every shell file (vendor payloads under */Docker/ excluded) ──
while IFS= read -r f; do
    bash -n "$f" 2>/dev/null || fail "syntax: $f"
done < <(find core modules tests -type f \( -name '*.bash' -o -name '*.sh' \) ! -path '*/Docker/*')
for f in core/shells/bash/.bashrc core/shells/bash/aliases/.aliases core/shells/bash/profiles/.*; do
    [ -f "$f" ] || continue
    bash -n "$f" 2>/dev/null || fail "syntax: $f"
done
echo "[1/6] syntax scan done"

# ── 2. shellcheck on core functions (repo .shellcheckrc applies) ──
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning core/shells/bash/functions/*.bash || fail "shellcheck: core functions"
    echo "[2/6] shellcheck done"
else
    echo "[2/6] WARN: shellcheck not installed, skipped"
fi

# ── 3. .bashrc loader integrity: every $project_path file it references exists ──
while IFS= read -r rel; do
    [ -e "$rel" ] || fail "loader target missing: $rel (referenced in .bashrc)"
done < <(grep -oE '\$project_path"?/[[:alnum:]._/-]+' core/shells/bash/.bashrc | sed 's|^\$project_path"\?/||' | sort -u)
echo "[3/6] loader integrity done"

# ── 4. alias integrity: every alias pointing into modules/ has an existing target ──
for af in core/shells/bash/aliases/.aliases core/shells/bash/aliases/.*.sh; do
    [ -f "$af" ] || continue
    while read -r name rel; do
        [ -z "${rel:-}" ] && continue
        [ -f "$rel" ] || fail "alias '$name' -> $rel: target missing (in $af)"
    done < <(grep -E 'alias [A-Za-z_0-9]+=.*modules/' "$af" \
             | sed 's/.*alias \([A-Za-z_0-9]*\)=.*modules\//\1 modules\//; s/["'"'"'].*//')
done
echo "[4/6] alias integrity done"

# ── 5. myshell func_files list matches reality and its printed total ──
func_line=$(grep -m1 'local func_files=' core/shells/bash/functions/myshell.bash | sed 's/.*="//; s/".*//')
n_listed=0
for fn in $func_line; do
    n_listed=$((n_listed + 1))
    [ -f "core/shells/bash/functions/${fn}.bash" ] || fail "func_files entry '$fn' has no file"
done
n_printed=$(grep -oE 'Total: %d/[0-9]+' core/shells/bash/functions/myshell.bash | grep -oE '[0-9]+$')
[ "$n_listed" = "${n_printed:-}" ] || fail "func_files count ($n_listed) != printed total (${n_printed:-none}) in myshell.bash"
echo "[5/6] func_files consistency done"

# ── 6. docker compose config + myshell smoke ──
if docker compose version >/dev/null 2>&1; then
    for d in modules/docker/*/; do
        compose=$(ls "$d"docker-compose.y*ml 2>/dev/null | head -1) || true
        [ -n "${compose:-}" ] || continue
        (cd "$d" && docker compose config --quiet) || fail "compose config: $d"
    done
else
    echo "WARN: docker compose unavailable, compose configs skipped"
fi
smoke=$(
    # shellcheck source=core/shells/bash/functions/myshell.bash
    # shellcheck disable=SC2155
    _tmp_dir="$(mktemp -d)"
    project_path="$root"
    export MY_SHELL_ENV_DIR="$_tmp_dir"
    source core/shells/bash/functions/myshell.bash && myshell list
    rm -rf "$_tmp_dir"
) || fail "myshell list crashed"
echo "$smoke" | grep -q "MODULE COMMANDS" || fail "myshell list: header missing"
n_cmds=$(echo "$smoke" | grep -c "\->") || true
[ "${n_cmds:-0}" -gt 0 ] || fail "myshell list: no commands listed"
echo "[6/6] compose + smoke done ($n_cmds commands listed)"

# ── 7. shellcheck on ALL module files (not just core functions) ──
# Flags only real issues: SC2164 (unsafe cd), SC2140 (bad quoting).
# SC2139 (alias expansion), SC2154 (var from .bashrc), SC1090 (dynamic source),
# SC2034 (unused/exported var) are expected in this framework.
# Vendor payloads (Docker/ catalina, tomcat startup) are excluded.
if command -v shellcheck >/dev/null 2>&1; then
    find core modules tests -type f \( -name '*.bash' -o -name '*.sh' \) \
        ! -path '*/Docker/*' -print0 | \
        xargs -0 shellcheck -S warning -e SC2139 -e SC2154 -e SC1090 -e SC2034 2>/dev/null \
        || fail "shellcheck: modules (real issues)"
    echo "[7/10] shellcheck (modules) done"
else
    echo "[7/10] WARN: shellcheck not installed, skipped modules"
fi

# ── 8. extensionless dot-files in core/shells/bash/ must have a shebang ──
for f in core/shells/bash/.bashrc core/shells/bash/.bash_profile \
         core/shells/bash/aliases/.aliases core/shells/bash/aliases/.base.sh \
         core/shells/bash/aliases/.docker.sh core/shells/bash/aliases/.git.sh \
         core/shells/bash/aliases/.modules.sh core/shells/bash/aliases/.utilities.sh \
         core/shells/bash/profiles/.appearance core/shells/bash/profiles/.completion \
         core/shells/bash/profiles/.config_files core/shells/bash/profiles/.git-configs \
         core/shells/bash/profiles/.history core/shells/bash/profiles/.path \
         core/shells/bash/profiles/.pwsh core/shells/bash/profiles/.software \
         core/shells/bash/profiles/.ssh; do
    [ -f "$f" ] || continue
    first_line=$(head -1 "$f")
    case "$first_line" in
        '#!'*) ;; # OK
        *) fail "shebang missing: $f (first line: '$first_line')" ;;
    esac
done
echo "[8/10] shebang on extensionless dot-files done"

# ── 9. no hardcoded ~/Documents/myshell/ paths in aliases ──
while IFS= read -r match; do
    fail "hardcoded path found: $match"
done < <(grep -rn "\$HOME/Documents/myshell/" core/shells/bash/aliases/ 2>/dev/null || true)
echo "[9/10] hardcoded path check done"

# ── 10. anti-patterns: grep -c | cat, pipe to grep, unquoted variables in test brackets ──
while IFS= read -r match; do
    fail "anti-pattern (cat | grep): $match"
done < <(grep -rn 'cat .*/.* | grep' core/shells/bash/aliases/ modules/ 2>/dev/null || true)
echo "[10/10] anti-pattern check done"

# ── verdict ──
if [ "$fails" -eq 0 ]; then
    echo "VALIDATION PASSED"
    exit 0
else
    echo "VALIDATION FAILED: $fails problem(s)"
    exit 1
fi
