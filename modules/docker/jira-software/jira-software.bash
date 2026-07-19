#!/bin/bash
cd "$project_path/modules/docker/jira-software" || exit 1
docker compose up --build --force-recreate
cd "$OLDPWD" || exit 1
