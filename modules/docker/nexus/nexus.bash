#!/bin/bash
cd "$project_path/modules/docker/nexus" || exit 1
docker compose up --build --force-recreate
cd "$OLDPWD" || exit 1
