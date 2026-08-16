#!/bin/bash
## Time lapse bash loading
initial_result=$(date +%s%3N)
# Jobs: display the last value immediately and keep the refresh worker alive.
[ -s "$HOME/public_ip.txt" ] && head -n 1 "$HOME/public_ip.txt"
bash "$project_path"/core/shells/bash/jobs/public_ip.bash &
# Load functions
if [ -f "$project_path"/core/shells/bash/functions/checks.bash ]; then
	. "$project_path"/core/shells/bash/functions/checks.bash
fi
if [ -f "$project_path"/core/shells/bash/functions/colors.bash ]; then
	. "$project_path"/core/shells/bash/functions/colors.bash
fi
if [ -f "$project_path"/core/shells/bash/functions/crlf_to_lf.bash ]; then
	. "$project_path"/core/shells/bash/functions/crlf_to_lf.bash
fi
if [ -f "$project_path"/core/shells/bash/functions/shfmt.bash ]; then
	. "$project_path"/core/shells/bash/functions/shfmt.bash
fi
if [ -f "$project_path"/core/shells/bash/functions/yamlfmt.bash ]; then
	. "$project_path"/core/shells/bash/functions/yamlfmt.bash
fi
if [ -f "$project_path"/core/shells/bash/functions/hadolint.bash ]; then
	. "$project_path"/core/shells/bash/functions/hadolint.bash
fi
if [ -f "$project_path"/core/shells/bash/functions/myshell.bash ]; then
	. "$project_path"/core/shells/bash/functions/myshell.bash
	myshell_state_init
fi
if [ -f "$project_path"/core/shells/bash/functions/shellcheck.bash ]; then
	. "$project_path"/core/shells/bash/functions/shellcheck.bash
fi
# Load aliases. Only .aliases is sourced, and deliberately so: this used to glob the
# whole directory, so any leftover file there was sourced AFTER .aliases and silently
# overrode it. Untracked strays (.base.sh, .git.sh, .modules.sh from an old layout) did
# exactly that on a live machine — they redefined tfi and ghard without their
# confirmation prompts and redefined module aliases with no myshell_module_enabled
# check, which disabled the whole enable/disable feature. .aliases is the single source.
alias_file="$project_path/core/shells/bash/aliases/.aliases"
[ -f "$alias_file" ] && . "$alias_file"
unset alias_file
# Load enabled profiles in their established order.
for profile_name in .git-configs .appearance .completion .history .path .pwsh .software .config_files .ssh; do
	profile_file="$project_path/core/shells/bash/profiles/$profile_name"
	if [ -f "$profile_file" ] && myshell_profile_enabled "$profile_name"; then
		. "$profile_file"
	fi
done
unset profile_name profile_file
# Bash time lapse ends
final_result=$(date +%s%3N)
elapsed_time=$((final_result - initial_result))
seconds=$((elapsed_time / 1000))
milliseconds=$((elapsed_time % 1000))
echo -e '\033[1;33m'"Execution time was ${seconds}.${milliseconds} seconds."'\e[1;37m'
