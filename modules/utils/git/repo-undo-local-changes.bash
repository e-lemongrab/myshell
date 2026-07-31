#!/usr/bin/env bash

set -euo pipefail

changed_repositories=()
for directory in */; do
	[ -d "$directory/.git" ] || continue
	if git -C "$directory" diff --quiet && git -C "$directory" diff --cached --quiet; then
		continue
	fi
	changed_repositories+=("${directory%/}")
done

if [ "${#changed_repositories[@]}" -eq 0 ]; then
	printf 'No child repositories contain local changes.\n'
	exit 0
fi

printf 'Child repositories with tracked changes that will be reset:\n'
for directory in "${changed_repositories[@]}"; do
	printf '\n[%s]\n' "$directory"
	git -C "$directory" status --short
done

printf '\nUntracked files are not removed. Type RESET ALL to continue: '
read -r confirmation
[ "$confirmation" = "RESET ALL" ] || {
	printf 'Cancelled.\n'
	exit 0
}

for directory in "${changed_repositories[@]}"; do
	git -C "$directory" reset --hard
done

printf 'Changes were reset in:\n'
printf '  %s\n' "${changed_repositories[@]}"
