#!/bin/bash
cd "$project_path/modules/docker/alpine"
docker compose up -d --build --force-recreate
cd
