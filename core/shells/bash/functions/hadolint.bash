#!/bin/bash
docker_files() {
	sub_dir=/tmp/"$RANDOM"
    find ./ -type f -name '.Dockerfile' -not -path '*/.*/*' 1>"$sub_dir"
    for relative_path in $(cat "$sub_dir"); do
        hadolint "$relative_path"
    done
    rm -f "$sub_dir"
}
export -f docker_files
