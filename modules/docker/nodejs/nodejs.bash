#!/bin/bash
cd "$project_path/modules/docker/nodejs" || exit 1
docker compose up --build -d --force-recreate
cd "$OLDPWD" || exit 1
