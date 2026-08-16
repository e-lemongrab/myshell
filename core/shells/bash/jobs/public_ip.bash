#!/usr/bin/env bash

set -u

cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/myshell"
cache_file="$HOME/public_ip.txt"
lock_dir="$cache_root/public-ip.lock"
# Strategy: event-driven public-IP detection.
#   - Poll local egress source IP every 2s. When it changes → fetch public IP now.
#   - Also force a fetch at most every ttl_seconds even if no local change (safety net).
#   - The dir-lock + mtime gate keep it to ~one external request per ttl_seconds
#     machine-wide, regardless of how many terminals are open.
ttl_seconds=30
loop_seconds=2
lock_owned=0
last_src_ip=""  # cached local egress source IP for change detection

mkdir -p "$cache_root" || exit 1

release_lock() {
	if [ "$lock_owned" -eq 1 ]; then
		rmdir "$lock_dir" 2>/dev/null || true
		lock_owned=0
	fi
}

# Fetch the local egress source IP (zero external requests)
get_local_egress_ip() {
	ip route get 1.1.1.1 2>/dev/null | awk '/src/ {print $NF; exit}'
}

# Actually fetch public IP from ifconfig.me; bypass TTL gate when $1 == "force"
refresh_public_ip() {
	local _force="${1:-no}"
	local age real_ip current_line new_line temporary_file

	# Skip if cache is fresh and not forced
	if [ "$_force" != "force" ] && [ -f "$cache_file" ]; then
		age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || printf '0')))
		[ "$age" -lt "$ttl_seconds" ] && return 0
	fi

	mkdir "$lock_dir" 2>/dev/null || return 0
	lock_owned=1

	real_ip=$(curl --fail --silent --show-error --connect-timeout 2 --max-time 5 \
		https://ifconfig.me/ip 2>/dev/null) || {
		release_lock
		return 0
	}
	real_ip=${real_ip//$'\r'/}
	real_ip=${real_ip//$'\n'/}
	[ -n "$real_ip" ] || {
		release_lock
		return 0
	}

	current_line=""
	[ ! -f "$cache_file" ] || IFS= read -r current_line <"$cache_file"
	new_line="Public IP: $real_ip"
	if [ "$new_line" != "$current_line" ]; then
		temporary_file="${cache_file}.tmp.$$"
		printf '%s\n' "$new_line" >"$temporary_file"
		mv "$temporary_file" "$cache_file"
		printf '%s\n' "$new_line"
	else
		touch "$cache_file"
	fi
	release_lock
}

trap release_lock EXIT
trap 'exit 0' HUP INT TERM

# --- Main loop: detect local egress IP changes → fetch public IP on change ---
while true; do
	current_src_ip=$(get_local_egress_ip)

	if [ -n "$current_src_ip" ]; then
		# Local egress changed → immediately check public IP
		if [ "$current_src_ip" != "$last_src_ip" ]; then
			refresh_public_ip "force"
			last_src_ip="$current_src_ip"
		fi
	fi

	# Safety-net: if we haven't fetched recently, force one
	refresh_public_ip

	sleep "$loop_seconds"
done
