#!/bin/bash
shellcheck_files() {
	sub_dir=/tmp/"$RANDOM"
    find ./ -type f -not -path '*/.*' \( -name '*.bash' -o -name '*.sh' \) 1>"$sub_dir"
    for relative_path in $(cat "$sub_dir"); do
        #echo $relative_path
        shellcheck "$relative_path"
    done
    rm -f "$sub_dir"
}
export -f shellcheck_files
