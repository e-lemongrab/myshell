#!/bin/bash
yamlfmt_files() {
	sub_dir=/tmp/"$RANDOM"
    find ./ -type f -not -path '*/.*' \( -name '*.yaml' -o -name '*.yml' \) 1>"$sub_dir"
    for relative_path in $(cat "$sub_dir"); do
    # Check if the file contains 'kind: ConfigMap', if true then discard file to modify
        if ! grep -q 'kind: ConfigMap' "$relative_path"; then
            yamlfmt "$relative_path"
        fi
    done
    rm -f "$sub_dir"
}
export -f yamlfmt_files

# hadolint
# PSScriptAnalyzer
