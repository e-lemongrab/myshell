#!/bin/bash
# myshell - framework state and interactive management

myshell_state_dir() {
	if [[ -n "${MY_SHELL_ENV_DIR:-}" && "$MY_SHELL_ENV_DIR" != "/" ]]; then
		printf '%s/module_state\n' "$MY_SHELL_ENV_DIR"
	else
		printf '%s/.module_state\n' "$project_path"
	fi
}

myshell_collect_modules() {
	local category category_name module found

	for category in "$project_path"/modules/*/; do
		[ -d "$category" ] || continue
		category_name=$(basename "$category")
		found=0
		for module in "$category"*/; do
			[ -d "$module" ] || continue
			found=1
			printf '%s/%s\n' "$category_name" "$(basename "$module")"
		done
		[ "$found" -eq 0 ] && printf '%s\n' "$category_name"
	done | sort -u
}

myshell_collect_profiles() {
	local profile

	for profile in "$project_path"/core/shells/bash/profiles/.*; do
		[ -f "$profile" ] && basename "$profile"
	done | sort -u
}

myshell_state_init() {
	local state_dir module_file profile_file current_modules migration line match

	state_dir=$(myshell_state_dir)
	module_file="$state_dir/enabled.modules"
	profile_file="$state_dir/enabled.profiles"
	mkdir -p "$state_dir" 2>/dev/null || return 1

	if [ ! -f "$module_file" ]; then
		myshell_collect_modules >"$module_file"
	elif [ -s "$module_file" ]; then
		# Migrate the previous basename-only format. Ambiguous names deliberately
		# enable every matching full ID so an upgrade cannot silently disable one.
		# Idempotent: only run when the state still holds legacy basename-only
		# entries. A state that is already full-ID is left untouched, so
		# `myshell disable` survives reloads and new modules are enabled via the
		# menu (not force-added), keeping the enable/disable contract intact.
		current_modules=$(myshell_collect_modules)
		legacy_found=0
		while IFS= read -r line; do
			[ -n "$line" ] || continue
			case "$line" in */*) : ;; *) legacy_found=1 ;; esac
		done <"$module_file"
		if [ "$legacy_found" -eq 0 ]; then
			return 0
		fi
		migration="${module_file}.tmp.$$"
		: >"$migration" || return 1
		while IFS= read -r line; do
			[ -n "$line" ] || continue
			if grep -qxF "$line" <<<"$current_modules"; then
				printf '%s\n' "$line" >>"$migration"
				continue
			fi
			while IFS= read -r match; do
				[ "${match##*/}" = "$line" ] && printf '%s\n' "$match" >>"$migration"
			done <<<"$current_modules"
		done <"$module_file"
		sort -u "$migration" -o "$migration"
		mv "$migration" "$module_file"
	fi

	# Profiles used to load unconditionally. Keep that behaviour on migration.
	[ -f "$profile_file" ] || myshell_collect_profiles >"$profile_file"
}

myshell_module_enabled() {
	local module_file
	module_file="$(myshell_state_dir)/enabled.modules"
	grep -qxF "$1" "$module_file" 2>/dev/null
}

myshell_profile_enabled() {
	local profile_file
	profile_file="$(myshell_state_dir)/enabled.profiles"
	grep -qxF "$1" "$profile_file" 2>/dev/null
}

myshell() {
	local cmd="${1:-menu}" state_dir module_file profile_file
	shift 2>/dev/null || true

	myshell_state_init || {
		printf 'myshell: could not initialize state\n' >&2
		return 1
	}
	state_dir=$(myshell_state_dir)
	module_file="$state_dir/enabled.modules"
	profile_file="$state_dir/enabled.profiles"

	c_green() { printf '\033[0;32m%s\033[0m' "$1"; }
	c_red() { printf '\033[0;31m%s\033[0m' "$1"; }
	c_yellow() { printf '\033[0;33m%s\033[0m' "$1"; }
	c_blue() { printf '\033[0;34m%s\033[0m' "$1"; }
	c_white() { printf '\033[1;37m%s\033[0m' "$1"; }

	_state_enable() {
		local name="$1" file="$2"
		grep -qxF "$name" "$file" 2>/dev/null && return 0
		printf '%s\n' "$name" >>"$file"
		sort -u "$file" -o "$file"
	}

	_state_disable() {
		local name="$1" file="$2" tmp="${2}.tmp.$$" rc=0
		grep -vxF "$name" "$file" >"$tmp" 2>/dev/null || rc=$?
		if [ "$rc" -le 1 ]; then
			mv "$tmp" "$file"
		else
			rm -f "$tmp"
			return 1
		fi
	}

	_module_exists() {
		myshell_collect_modules | grep -qxF "$1"
	}

	_profile_exists() {
		myshell_collect_profiles | grep -qxF "$1"
	}

	_mod_enable() {
		local name="$1"
		[ -n "$name" ] || {
			printf 'Usage: myshell enable <category/module>\n' >&2
			return 1
		}
		_module_exists "$name" || {
			printf 'Unknown module: %s\n' "$name" >&2
			return 1
		}
		_state_enable "$name" "$module_file"
		c_green "Enabled: $name"
		printf ' (run reload_shell or exec -l "$SHELL" to apply)\n'
	}

	_mod_disable() {
		local name="$1"
		[ -n "$name" ] || {
			printf 'Usage: myshell disable <category/module>\n' >&2
			return 1
		}
		_module_exists "$name" || {
			printf 'Unknown module: %s\n' "$name" >&2
			return 1
		}
		_state_disable "$name" "$module_file"
		c_red "Disabled: $name"
		printf ' (run reload_shell or exec -l "$SHELL" to apply)\n'
	}

	_profile_enable() {
		local name="$1"
		[ -n "$name" ] || {
			printf 'Usage: myshell profile-enable <.profile>\n' >&2
			return 1
		}
		_profile_exists "$name" || {
			printf 'Unknown profile: %s\n' "$name" >&2
			return 1
		}
		_state_enable "$name" "$profile_file"
		c_green "Enabled profile: $name"
		printf ' (run reload_shell or exec -l "$SHELL" to apply)\n'
	}

	_profile_disable() {
		local name="$1"
		[ -n "$name" ] || {
			printf 'Usage: myshell profile-disable <.profile>\n' >&2
			return 1
		}
		_profile_exists "$name" || {
			printf 'Unknown profile: %s\n' "$name" >&2
			return 1
		}
		_state_disable "$name" "$profile_file"
		c_red "Disabled profile: $name"
		printf ' (run reload_shell or exec -l "$SHELL" to apply)\n'
	}

	_cat_enable() {
		local category="$1" module found=0
		while IFS= read -r module; do
			case "$module" in
			"$category"|"$category"/*)
				_state_enable "$module" "$module_file"
				found=1
				;;
			esac
		done < <(myshell_collect_modules)
		[ "$found" -eq 1 ]
	}

	_cat_disable() {
		local category="$1" module
		while IFS= read -r module; do
			case "$module" in
			"$category"|"$category"/*) _state_disable "$module" "$module_file" ;;
			esac
		done < <(myshell_collect_modules)
	}

	do_status() {
		local module profile enabled=0 total=0 aliases=0

		printf '\n'
		c_green "========================================="
		printf '\n'
		c_white "  myshell Framework Status"
		printf '\n'
		c_green "========================================="
		printf '\n\n'

		c_blue "MODULES:"
		printf '\n'
		while IFS= read -r module; do
			((total++)) || true
			if myshell_module_enabled "$module"; then
				((enabled++)) || true
				c_green "  [+] $module"
				printf '\n'
			else
				printf '  [ ] %s\n' "$module"
			fi
		done < <(myshell_collect_modules)
		printf '  Total: %d/%d enabled\n\n' "$enabled" "$total"

		c_blue "PROFILES:"
		printf '\n'
		while IFS= read -r profile; do
			if myshell_profile_enabled "$profile"; then
				c_green "  [+] $profile"
				printf '\n'
			else
				printf '  [ ] %s\n' "$profile"
			fi
		done < <(myshell_collect_profiles)
		printf '\n'

		c_blue "ALIASES:"
		printf '\n'
		aliases=$(alias 2>/dev/null | wc -l)
		printf '  %d loaded in this shell\n\n' "$aliases"

		c_blue "PROJECT:"
		printf '\n'
		if command -v git >/dev/null 2>&1 && [ -d "$project_path/.git" ]; then
			printf '  %s@%s' "$(basename "$project_path")" "$(git -C "$project_path" branch --show-current 2>/dev/null)"
			if [ -z "$(git -C "$project_path" status --porcelain 2>/dev/null)" ]; then
				c_green " (clean)"
			else
				c_yellow " (dirty)"
			fi
			printf '\n'
		else
			printf '  %s\n' "$project_path"
		fi
		printf '\n'
	}

	do_cmds_list() {
		local aliases_file="$project_path/core/shells/bash/aliases/.aliases"
		local line name rel first rest second module found=0 seen=" "

		printf '\n'
		c_blue "MODULE COMMANDS (alias -> module script):"
		printf '\n'
		while IFS= read -r line; do
			case "$line" in
			*"alias "*=*modules/*) ;;
			*) continue ;;
			esac
			name="${line#*alias }"
			name="${name%%=*}"
			case "$seen" in *" $name "*) continue ;; esac
			seen="$seen$name "
			rel="${line#*modules/}"
			rel="${rel%%\"*}"
			rel="${rel%%\'*}"
			[ -f "$project_path/modules/$rel" ] || continue
			first="${rel%%/*}"
			rest="${rel#*/}"
			second="${rest%%/*}"
			module="$first"
			[ -d "$project_path/modules/$first/$second" ] && module="$first/$second"
			myshell_module_enabled "$module" || continue
			printf '  \033[0;32m%-28s\033[0m -> %s\n' "$name" "$rel"
			found=1
		done <"$aliases_file"
		[ "$found" -eq 0 ] && printf '  (none)\n'
		printf '\n'
	}

	do_manage_modules() {
		local -a names=() statuses=()
		local category module current previous="" all_enabled=1 sel=0 choice

		while IFS= read -r module; do
			category="${module%%/*}"
			[ "$category" = "$previous" ] && continue
			names+=("$category")
			previous="$category"
		done < <(myshell_collect_modules)
		[ "${#names[@]}" -gt 0 ] || return 0

		while true; do
			statuses=()
			for category in "${names[@]}"; do
				all_enabled=1
				while IFS= read -r module; do
					case "$module" in
					"$category"|"$category"/*)
						myshell_module_enabled "$module" || all_enabled=0
						;;
					esac
				done < <(myshell_collect_modules)
				[ "$all_enabled" -eq 1 ] && statuses+=("ON") || statuses+=("OFF")
			done
			printf '\n'
			c_blue "MODULE CATEGORIES (number toggles, q returns):"
			printf '\n'
			for ((sel = 0; sel < ${#names[@]}; sel++)); do
				printf '  %d) [%-3s] %s\n' "$((sel + 1))" "${statuses[$sel]}" "${names[$sel]}"
			done
			printf 'Choice: '
			read -r choice || return 0
			case "$choice" in
			q | Q) return 0 ;;
			*[!0-9]* | "") c_yellow "Unknown option."; printf '\n' ;;
			*)
				sel=$((choice - 1))
				if [ "$sel" -ge 0 ] && [ "$sel" -lt "${#names[@]}" ]; then
					if [ "${statuses[$sel]}" = "ON" ]; then
						_cat_disable "${names[$sel]}"
					else
						_cat_enable "${names[$sel]}"
					fi
					printf 'State saved; run reload_shell or exec -l "$SHELL" to apply it.\n'
				fi
				;;
			esac
		done
	}

	do_manage_profiles() {
		local -a names=()
		local profile index=0 choice

		while IFS= read -r profile; do names+=("$profile"); done < <(myshell_collect_profiles)
		while true; do
			printf '\n'
			c_blue "PROFILES (number toggles, q returns):"
			printf '\n'
			for ((index = 0; index < ${#names[@]}; index++)); do
				if myshell_profile_enabled "${names[$index]}"; then
					printf '  %d) [ON ] %s\n' "$((index + 1))" "${names[$index]}"
				else
					printf '  %d) [OFF] %s\n' "$((index + 1))" "${names[$index]}"
				fi
			done
			printf 'Choice: '
			read -r choice || return 0
			case "$choice" in
			q | Q) return 0 ;;
			*[!0-9]* | "") c_yellow "Unknown option."; printf '\n' ;;
			*)
				index=$((choice - 1))
				if [ "$index" -ge 0 ] && [ "$index" -lt "${#names[@]}" ]; then
					if myshell_profile_enabled "${names[$index]}"; then
						_state_disable "${names[$index]}" "$profile_file"
					else
						_state_enable "${names[$index]}" "$profile_file"
					fi
					printf 'State saved; run reload_shell or exec -l "$SHELL" to apply it.\n'
				fi
				;;
			esac
		done
	}

	do_menu() {
		local choice
		while true; do
			printf '\n'
			c_white "myshell - Framework Manager"
			printf '\n\n  1) Show framework status\n  2) Manage modules\n  3) Manage profiles\n  4) List module commands\n  q) Quit\n\nChoice: '
			read -r choice || return 0
			case "$choice" in
			1) do_status ;;
			2) do_manage_modules ;;
			3) do_manage_profiles ;;
			4) do_cmds_list ;;
			q | Q) return 0 ;;
			*) c_yellow "Unknown option."; printf '\n' ;;
			esac
		done
	}

	case "$cmd" in
	status) do_status ;;
	list) do_cmds_list ;;
	enable) _mod_enable "${1:-}" ;;
	disable) _mod_disable "${1:-}" ;;
	profile-enable) _profile_enable "${1:-}" ;;
	profile-disable) _profile_disable "${1:-}" ;;
	menu | "") do_menu ;;
	*)
		printf 'Usage: myshell [status|list|enable MODULE|disable MODULE|profile-enable PROFILE|profile-disable PROFILE]\n'
		return 1
		;;
	esac
}
