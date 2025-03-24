## Time lapse bash loading
initial_result=$(date +%s%3N)
# Jobs
bash "$project_path"/core/shells/bash/jobs/public_ip.bash &
sleep 1.5
#bash "$project_path"/core/shells/bash/jobs/online_users.bash&
# sleep 1
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
fi
if [ -f "$project_path"/core/shells/bash/functions/shellcheck.bash ]; then
	. "$project_path"/core/shells/bash/functions/shellcheck.bash
fi
# Load aliases
if [ -f "$project_path"/core/shells/bash/aliases/.aliases ]; then
	. "$project_path"/core/shells/bash/aliases/.aliases
fi
if [ -f "$project_path"/core/shells/bash/aliases/.aliases_work ]; then
	. "$project_path"/core/shells/bash/aliases/.aliases_work
fi
# Load profiles
if [ -f "$project_path"/core/shells/bash/profiles/.git-configs ]; then
	. "$project_path"/core/shells/bash/profiles/.git-configs
fi
if [ -f "$project_path"/core/shells/bash/profiles/.appearance ]; then
	. "$project_path"/core/shells/bash/profiles/.appearance
fi
if [ -f "$project_path"/core/shells/bash/profiles/.completion ]; then
	. "$project_path"/core/shells/bash/profiles/.completion
fi
if [ -f "$project_path"/core/shells/bash/profiles/.history ]; then
	. "$project_path"/core/shells/bash/profiles/.history
fi
if [ -f "$project_path"/core/shells/bash/profiles/.path ]; then
	. "$project_path"/core/shells/bash/profiles/.path
fi
if [ -f "$project_path"/core/shells/bash/profiles/.pwsh ]; then
	. "$project_path"/core/shells/bash/profiles/.pwsh
fi
if [ -f "$project_path"/core/shells/bash/profiles/.software ]; then
	. "$project_path"/core/shells/bash/profiles/.software
fi
if [ -f "$project_path"/core/shells/bash/profiles/.config_files ]; then
	. "$project_path"/core/shells/bash/profiles/.config_files
fi
if [ -f "$project_path"/core/shells/bash/profiles/.ssh ]; then
	. "$project_path"/core/shells/bash/profiles/.ssh
fi
# Bash time lapse ends
final_result=$(date +%s%3N)
elapsed_time=$((final_result - initial_result))
seconds=$((elapsed_time / 1000))
milliseconds=$((elapsed_time % 1000))
echo -e '\033[1;33m'"Execution time was ${seconds}.${milliseconds} seconds."'\e[1;37m'