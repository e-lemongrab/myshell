#!/bin/bash
cd "$project_path/modules/docker/alpine" || exit 1
docker exec -it alpine /bin/sh
