#!/usr/bin/env bash

set -euo pipefail

command -v docker >/dev/null 2>&1 || {
	printf 'Docker is not installed.\n' >&2
	exit 1
}
docker info >/dev/null 2>&1 || {
	printf 'Docker is not available for the current user.\n' >&2
	exit 1
}

printf 'Containers that will be removed:\n'
docker ps -a --format '  {{.ID}}\t{{.Names}}\t{{.Status}}'
printf '\nImages that will be removed:\n'
docker image ls -a --format '  {{.ID}}\t{{.Repository}}:{{.Tag}}' | sort -u
printf '\nVolumes that will be removed:\n'
docker volume ls --format '  {{.Name}}'
printf '\nUnused custom networks that will be pruned:\n'
docker network ls --filter type=custom --format '  {{.ID}}\t{{.Name}}'

printf '\nThis affects the entire local Docker daemon. Type DELETE DOCKER DATA to continue: '
read -r confirmation
[ "$confirmation" = "DELETE DOCKER DATA" ] || {
	printf 'Cancelled.\n'
	exit 0
}

mapfile -t container_ids < <(docker ps -aq)
mapfile -t image_ids < <(docker image ls -aq | sort -u)
mapfile -t volume_names < <(docker volume ls -q)

[ "${#container_ids[@]}" -eq 0 ] || docker rm -f "${container_ids[@]}"
[ "${#image_ids[@]}" -eq 0 ] || docker image rm -f "${image_ids[@]}"
[ "${#volume_names[@]}" -eq 0 ] || docker volume rm "${volume_names[@]}"
docker network prune --force

printf 'Docker cleanup completed.\n'
