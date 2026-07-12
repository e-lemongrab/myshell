#!/bin/bash
shfmt_files() {
	sub_dir=/tmp/"$RANDOM"
	# The following command does not work with hidden directories/files
	find ./ -type d -not -path '*/.*' 1>"$sub_dir"
	for relative_path in $(cat "$sub_dir"); do
		find "$relative_path" \
			-type f \( -name '*.bash' -o -name '*.sh' -o -name '.bashrc' -o -name '.bash_profile' -o -name '*.zsh' -o -name '*.ksh' \) \
			-exec shfmt -w {} \; # Use shfmt to format various shell script files
	done
	rm -f "$sub_dir"
}
export -f shfmt_files
