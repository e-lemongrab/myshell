#!/usr/bin/env bash

set -u

cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/myshell"
cache_file="$HOME/public_ip.txt"
lock_dir="$cache_root/public-ip.lock"
ttl_seconds=600

mkdir -p "$cache_root" || exit 1
if [ -f "$cache_file" ]; then
	age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || printf '0')))
	[ "$age" -lt "$ttl_seconds" ] && exit 0
fi

mkdir "$lock_dir" 2>/dev/null || exit 0
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT

real_ip=$(curl --fail --silent --show-error --connect-timeout 2 --max-time 5 https://ifconfig.me/ip 2>/dev/null) || exit 0
real_ip=${real_ip//$'\r'/}
real_ip=${real_ip//$'\n'/}
[ -n "$real_ip" ] || exit 0

temporary_file="${cache_file}.tmp.$$"
printf 'Public IP: %s\n' "$real_ip" >"$temporary_file" && mv "$temporary_file" "$cache_file"
