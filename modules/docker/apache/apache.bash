#!/bin/bash
cd "$project_path/modules/docker/apache" || exit 1
docker compose up -d --build --force-recreate
