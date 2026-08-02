#!/usr/bin/env bash

set -u

cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/myshell"
cache_file="$HOME/public_ip.txt"
lock_dir="$cache_root/public-ip.lock"
# Detection cadence: an actual ifconfig.me fetch only fires when the cache is
# older than ttl_seconds, so this is what gates how fast an IP/VPN change is
# noticed (~30s here). poll_seconds must stay <= ttl_seconds or it adds lag.
# The dir-lock + mtime gate keep it to ~one external request per ttl_seconds
# machine-wide, regardless of how many terminals are open.
ttl_seconds=30
poll_seconds=15
lock_owned=0

mkdir -p "$cache_root" || exit 1

release_lock() {
	if [ "$lock_owned" -eq 1 ]; then
		rmdir "$lock_dir" 2>/dev/null || true
		lock_owned=0
	fi
}

refresh_public_ip() {
	local age real_ip current_line new_line temporary_file

	if [ -f "$cache_file" ]; then
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

while true; do
	refresh_public_ip
	sleep "$poll_seconds"
done
