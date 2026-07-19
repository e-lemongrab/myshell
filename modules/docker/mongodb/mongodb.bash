#!/bin/bash
cd "$project_path/modules/docker/mongodb" || exit 1
case "$1" in
  arm)
    echo "[mongodb] Starting in ARM64 mode..."
    export DOCKER_DEFAULT_PLATFORM=linux/arm64
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
    docker compose up -d --build --force-recreate
    ;;
  *)
    echo "[mongodb] Starting in native amd64 mode..."
    docker compose up -d --build --force-recreate
    unset DOCKER_DEFAULT_PLATFORM
    unset DOCKER_BUILDKIT
    unset COMPOSE_DOCKER_CLI_BUILD
    ;;
esac
cd "$OLDPWD" || exit 1
