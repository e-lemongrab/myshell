#!/usr/bin/env bash
# Repository validation gate. Run from anywhere with: bash tests/validate.bash

set -u

cd "$(dirname "$0")/.." || exit 1
root=$PWD
failures=0
temporary_root=""

fail() {
	printf 'FAIL: %s\n' "$1"
	failures=$((failures + 1))
}

cleanup() {
	[ -z "$temporary_root" ] || rm -rf -- "$temporary_root"
}
trap cleanup EXIT

# 1. Parse every maintained shell file, including Docker entrypoints.
while IFS= read -r file; do
	bash -n "$file" 2>/dev/null || fail "shell syntax: $file"
done < <(find core modules tests -type f \( -name '*.bash' -o -name '*.sh' \) | sort)
for file in core/shells/bash/.bashrc core/shells/bash/.bash_profile \
	core/shells/bash/aliases/.aliases core/shells/bash/profiles/.*; do
	[ -f "$file" ] || continue
	bash -n "$file" 2>/dev/null || fail "shell syntax: $file"
done
printf '[1/11] shell syntax\n'

# 2. ShellCheck all scripts for errors and critical runtime files for warnings.
if command -v shellcheck >/dev/null 2>&1; then
	find core modules tests -type f \( -name '*.bash' -o -name '*.sh' \) -print0 |
		xargs -0 shellcheck -S error -e SC1090 -e SC1091 ||
		fail "ShellCheck error scan"

	critical_files=(
		core/shells/bash/.bashrc
		core/shells/bash/functions/myshell.bash
		core/shells/bash/aliases/.aliases
		core/shells/bash/jobs/public_ip.bash
		core/shells/bash/profiles/.appearance
		core/shells/bash/profiles/.completion
		core/shells/bash/profiles/.config_files
		core/shells/bash/profiles/.software
		core/shells/bash/profiles/.ssh
		modules/utils/linux_scripts/format_disk_ext4.bash
		modules/utils/git/repo-undo-local-changes.bash
		modules/docker/dock/dockrm.bash
		modules/docker/mongodb/Docker/entrypoint.sh
		modules/docker/mysql5/Docker/custom-docker-entrypoint.bash
		modules/docker/mysql8/Docker/custom-docker-entrypoint.bash
		modules/docker/nodejs/Docker/docker-entrypoint.bash
		modules/docker/syslog/Docker/basa-docker-entrypoint.bash
		modules/docker/tomcat9/Docker/entrypoint.bash
	)
	shellcheck -S warning -e SC1090 -e SC1091 -e SC2139 -e SC2154 -e SC2034 \
		"${critical_files[@]}" || fail "ShellCheck warning scan on runtime-critical files"
else
	printf 'WARN: shellcheck is unavailable; static shell analysis skipped\n'
fi
printf '[2/11] shell static analysis\n'

# 3. Every literal loader and alias target must exist.
while IFS= read -r relative_path; do
	[ -e "$relative_path" ] || fail "loader target missing: $relative_path"
done < <(
	grep -oE '\$project_path"?/[[:alnum:]._/-]+' core/shells/bash/.bashrc |
		sed 's|^\$project_path"\?/||' |
		sort -u
)

while IFS='|' read -r alias_name relative_path; do
	[ -n "$relative_path" ] || continue
	[ -f "$relative_path" ] || fail "alias '$alias_name' points to missing $relative_path"
done < <(
	sed -nE 's@.*alias ([A-Za-z_0-9]+)=.*modules/([^"'"'"' ]+).*@\1|modules/\2@p' \
		core/shells/bash/aliases/.aliases
)
printf '[3/11] loader and alias targets\n'

# 4. A fresh state enables every full module ID and every profile.
temporary_root=$(mktemp -d)
export MY_SHELL_ENV_DIR="$temporary_root/default"
project_path="$root"
# shellcheck source=core/shells/bash/functions/myshell.bash
. core/shells/bash/functions/myshell.bash
myshell_state_init || fail "state initialization"

expected_modules=$(myshell_collect_modules)
enabled_modules=$(sort -u "$MY_SHELL_ENV_DIR/module_state/enabled.modules")
[ "$enabled_modules" = "$expected_modules" ] || fail "not every module is enabled by default"
printf '%s\n' "$enabled_modules" | grep -qxF "help/git" || fail "help/git full ID missing"
printf '%s\n' "$enabled_modules" | grep -qxF "utils/git" || fail "utils/git full ID missing"

expected_profiles=$(myshell_collect_profiles)
enabled_profiles=$(sort -u "$MY_SHELL_ENV_DIR/module_state/enabled.profiles")
[ "$enabled_profiles" = "$expected_profiles" ] || fail "not every profile is enabled by default"

# shellcheck source=core/shells/bash/aliases/.aliases
. core/shells/bash/aliases/.aliases
for alias_name in cls reload_shell gp tmuxon tfi bw alpine bw_clone help_git john_zip check_domains download; do
	alias "$alias_name" >/dev/null 2>&1 || fail "default alias unavailable: $alias_name"
done

# The alias loader must not glob its directory. It used to, which meant any stray file
# in aliases/ was sourced after .aliases and overrode it: tfi and ghard lost their
# confirmation prompts and module aliases stopped honouring the enable/disable state.
grep -q '"\$dir"/\.\*' core/shells/bash/.bashrc &&
	fail "the alias loader globs its directory again; a stray file there can override .aliases"
grep -qF 'aliases/.aliases' core/shells/bash/.bashrc ||
	fail "the alias loader no longer sources .aliases explicitly"

# Strays in aliases/ are inert now that the loader is explicit, but .gitignore hides
# them, so say so out loud rather than let them sit there unseen for months again.
stray_count=$(find core/shells/bash/aliases -maxdepth 1 -type f ! -name '.aliases' | wc -l)
[ "$stray_count" -eq 0 ] ||
	printf 'WARN: %d untracked file(s) in core/shells/bash/aliases/ besides .aliases; they are no longer sourced and can be deleted\n' "$stray_count"

# Whatever the loader does, the destructive wrappers must be what the shell resolves.
for guarded_alias in tfi:myshell_terraform_init_upgrade ghard:myshell_git_hard_reset; do
	alias_name=${guarded_alias%%:*}
	wrapper_name=${guarded_alias#*:}
	alias "$alias_name" 2>/dev/null | grep -qF "$wrapper_name" ||
		fail "$alias_name does not resolve to its confirmation wrapper $wrapper_name"
done
unset guarded_alias alias_name wrapper_name

myshell disable help/git >/dev/null || fail "disable help/git"
if MY_SHELL_ENV_DIR="$MY_SHELL_ENV_DIR" project_path="$root" bash --noprofile --norc -c '
	. core/shells/bash/functions/myshell.bash
	myshell_state_init
	. core/shells/bash/aliases/.aliases
	alias help_git >/dev/null 2>&1 && exit 1
	alias gs >/dev/null 2>&1
'; then
	:
else
	fail "module disable does not control aliases independently"
fi
printf '[4/11] module and profile state\n'

# 5. Migrate basename-only state without losing ambiguous modules.
migration_root="$temporary_root/migration"
mkdir -p "$migration_root/module_state"
printf 'git\narch\nbw\n' >"$migration_root/module_state/enabled.modules"
MY_SHELL_ENV_DIR="$migration_root" myshell_state_init || fail "legacy state migration"
for module_id in help/git utils/git help/arch bw; do
	grep -qxF "$module_id" "$migration_root/module_state/enabled.modules" ||
		fail "legacy migration missing $module_id"
done
printf '[5/11] legacy state migration\n'

# 6. Smoke-test command listing and the original cls failure mode.
export MY_SHELL_ENV_DIR="$temporary_root/smoke"
smoke_output=$(
	myshell_state_init
	myshell list
) || fail "myshell list crashed"
printf '%s\n' "$smoke_output" | grep -q "MODULE COMMANDS" || fail "myshell list header missing"
command_count=$(grep -c ' -> ' <<<"$smoke_output") || true
[ "$command_count" -gt 0 ] || fail "myshell list contains no commands"

TERM=xterm MY_SHELL_ENV_DIR="$temporary_root/interactive" project_path="$root" \
	bash --noprofile --norc -ic '
		. core/shells/bash/functions/myshell.bash
		myshell_state_init
		. core/shells/bash/aliases/.aliases
		alias cls >/dev/null
		eval cls
	' >/dev/null 2>&1 || fail "cls is not executable in a fresh interactive shell"
if grep -qF 'exec "$SHELL"' README.md; then
	fail 'README uses a non-login exec that bypasses .bash_profile'
fi
grep -q 'public_ip\.bash.*&$' core/shells/bash/.bashrc ||
	fail "public IP refresh is not launched as a background job"
grep -q '^while true; do$' core/shells/bash/jobs/public_ip.bash ||
	fail "public IP refresh is not persistent"
if grep -q 'disown' core/shells/bash/.bashrc; then
	fail "persistent shell job is removed from the job table"
fi
expected_os=$(
	. /etc/os-release
	printf '%s' "${PRETTY_NAME:-${NAME:-}}"
)
actual_os=$(AWS_PROFILE= bash --noprofile --norc -c '
	. core/shells/bash/profiles/.appearance
	printf "%s" "$OS_RELEASE"
')
[ "$actual_os" = "$expected_os" ] ||
	fail "prompt OS name does not match /etc/os-release PRETTY_NAME"
printf '[6/11] framework smoke tests (%d module commands)\n' "$command_count"

# 7. Validate YAML and every Compose model without starting containers.
if command -v yq >/dev/null 2>&1; then
	while IFS= read -r yaml_file; do
		yq . "$yaml_file" >/dev/null || fail "YAML syntax: $yaml_file"
	done < <(find .github modules -type f \( -name '*.yaml' -o -name '*.yml' \) | sort)
elif command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
	while IFS= read -r yaml_file; do
		python3 -c 'import pathlib, sys, yaml; yaml.safe_load(pathlib.Path(sys.argv[1]).read_text())' \
			"$yaml_file" >/dev/null || fail "YAML syntax: $yaml_file"
	done < <(find .github modules -type f \( -name '*.yaml' -o -name '*.yml' \) | sort)
else
	printf 'WARN: Python PyYAML is unavailable; generic YAML parse skipped\n'
fi

if docker compose version >/dev/null 2>&1; then
	while IFS= read -r compose_file; do
		compose_dir=$(dirname "$compose_file")
		(cd "$compose_dir" && docker compose -f "$(basename "$compose_file")" config --quiet) ||
			fail "Compose model: $compose_file"
	done < <(find modules/docker -maxdepth 2 -type f \( -name 'docker-compose.yaml' -o -name 'docker-compose.yml' \) | sort)
else
	printf 'WARN: docker compose is unavailable; Compose model validation skipped\n'
fi
printf '[7/11] YAML and Compose\n'

# 8. Docker build inputs must be canonical, present, bounded, and versioned.
while IFS= read -r legacy_dockerfile; do
	fail "legacy duplicate Dockerfile: $legacy_dockerfile"
done < <(find modules/docker -type f \( -name '.Dockerfile' -o -name 'dockerfile' \) | sort)

while IFS= read -r latest_reference; do
	fail "mutable Docker image reference: $latest_reference"
done < <(
	grep -RInE --include='Dockerfile' --include='*.yaml' --include='*.yml' \
		':latest' modules/docker || true
)

while IFS= read -r dockerfile; do
	context=$(cut -d/ -f1-3 <<<"$dockerfile")
	while IFS= read -r copy_line; do
		copy_arguments=${copy_line#COPY }
		case "$copy_arguments" in
		--from=*) continue ;;
		esac
		while [[ "$copy_arguments" == --* ]]; do copy_arguments=${copy_arguments#* }; done
		# Docker JSON-form COPY is not currently used in this repository.
		[[ "$copy_arguments" == \[* ]] && continue
		read -r -a copy_parts <<<"$copy_arguments"
		for ((index = 0; index < ${#copy_parts[@]} - 1; index++)); do
			source_path=${copy_parts[$index]#/}
			[[ "$source_path" == *'$'* ]] && continue
			if [[ "$source_path" == *[\*\?\[]* ]]; then
				compgen -G "$context/$source_path" >/dev/null ||
					fail "$dockerfile COPY source missing: $source_path"
			elif [ ! -e "$context/$source_path" ]; then
				fail "$dockerfile COPY source missing: $source_path"
			fi
		done
	done < <(grep '^COPY ' "$dockerfile")
done < <(find modules/docker -type f -name Dockerfile | sort)

while IFS= read -r dockerfile; do
	context=$(cut -d/ -f1-3 <<<"$dockerfile")
	[ -f "$context/.dockerignore" ] ||
		fail "missing .dockerignore in build context: $context"
done < <(find modules/docker -type f -name Dockerfile | sort)
printf '[8/11] Docker structure and versioning\n'

# 9. CI actions are immutable and every workflow declares its permissions.
[ ! -e .github/workflows/manual.yml ] || fail "manual.yml duplicates an existing workflow_dispatch"
while IFS= read -r action_reference; do
	action_value=${action_reference##*@}
	[[ "$action_value" =~ ^[0-9a-f]{40}([[:space:]]*#.*)?$ ]] ||
		fail "GitHub Action is not pinned to a commit: $action_reference"
done < <(sed -nE 's/^[[:space:]]*uses:[[:space:]]*//p' .github/workflows/*.yml)
# Checked per workflow present rather than by name: the previous version named
# schedule.yml explicitly, so removing that workflow left the gate failing on a
# file it no longer expected to exist.
while IFS= read -r workflow; do
	grep -q '^permissions:' "$workflow" || fail "workflow permissions missing: $workflow"
done < <(find .github/workflows -maxdepth 1 -name '*.yml' | sort)
printf '[9/11] CI policy\n'

# 10. Core portability rules and an informational personal-config inventory.
while IFS= read -r hardcoded_path; do
	fail "hardcoded repository path in aliases: $hardcoded_path"
done < <(grep -RInF '$HOME/Documents/myshell/' core/shells/bash/aliases || true)

personal_files=(
	core/shells/pwsh/HistoryFile.txt
	core/shells/pwsh/alias.ps1
	modules/utils/user_ssh/ansible/ansible
	modules/utils/user_ssh/ansible/authorized_keys
	modules/utils/user_ssh/hosts.txt
	modules/utils/user_ssh/hosts2.txt
)
personal_count=0
for personal_file in "${personal_files[@]}"; do
	[ -e "$personal_file" ] && personal_count=$((personal_count + 1))
done
printf '[10/11] portability; INFO: %d known personal/inventory files remain intentionally tracked\n' "$personal_count"

# 11. GitHub token manager: module wiring is a hard check; the live gh/git
# environment is reported (not enforced) because CI and fresh clones have no gh.
gh_module="modules/utils/gh-tokens/gh_tokens.bash"
[ -f "$gh_module" ] || fail "gh-tokens module script missing: $gh_module"
grep -q 'case "${1:-menu}" in' "$gh_module" ||
	fail "gh-tokens module has no subcommand entry point"
grep -qF 'utils/gh-tokens' core/shells/bash/aliases/.aliases ||
	fail "gh-tokens aliases not registered in .aliases"

gh_env_note=""
if command -v gh >/dev/null 2>&1; then
	git_helper=$(git config --global --get credential.https://github.com.helper 2>/dev/null)
	if [ -z "$git_helper" ]; then
		git_helper=$(git config --global --get credential.helper 2>/dev/null)
	fi
	# gh 2.x registers a "!" helper: !<path>/gh auth git-credential
	[[ "$git_helper" == *"gh auth git-credential"* || "$git_helper" == *gh-credential-gh* ]] ||
		gh_env_note="git credential helper not set to gh (run gh_git)"
else
	gh_env_note="gh CLI not installed (expected in CI)"
fi
if [ -n "$gh_env_note" ]; then
	printf 'WARN: %s\n' "$gh_env_note"
else
	printf 'INFO: gh + git credential helper configured\n'
fi
printf '[11/11] GitHub token manager\n'

if [ "$failures" -eq 0 ]; then
	printf 'VALIDATION PASSED\n'
	exit 0
fi

printf 'VALIDATION FAILED: %d problem(s)\n' "$failures"
exit 1
