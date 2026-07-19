#!/bin/bash
cd "$project_path/modules/docker/mysql8" || exit 1
docker compose up -d --build --force-recreate
cd "$OLDPWD" || exit 1
