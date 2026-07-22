#!/bin/bash
<<<<<<< HEAD
cd "$project_path/modules/docker/alpine" || exit 1
=======
cd "$project_path/modules/docker/alpine"
>>>>>>> 24d5e4e (fix: clean up broken code and update documentation)
docker compose up -d --build --force-recreate
cd "$OLDPWD" || exit 1
