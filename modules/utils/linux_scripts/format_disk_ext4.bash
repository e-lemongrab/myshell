#!/usr/bin/env bash

set -euo pipefail

for command_name in lsblk findmnt wipefs parted partprobe mkfs.ext4; do
	command -v "$command_name" >/dev/null 2>&1 || {
		printf 'Missing required command: %s\n' "$command_name" >&2
		exit 1
	}
done

root_source=$(findmnt -no SOURCE /)
mapfile -t system_disks < <(
	lsblk -nrspo NAME,TYPE "$root_source" 2>/dev/null |
		awk '$2 == "disk" { print $1 }' |
		sort -u
)
[ "${#system_disks[@]}" -gt 0 ] || {
	printf 'Unable to resolve the physical disk backing / (%s); refusing to continue.\n' "$root_source" >&2
	exit 1
}

mapfile -t all_disks < <(lsblk -e7 -dpno NAME,TYPE | awk '$2 == "disk" { print $1 }')
disks=()
for candidate_disk in "${all_disks[@]}"; do
	is_system_disk=0
	for system_disk in "${system_disks[@]}"; do
		if [ "$candidate_disk" = "$system_disk" ]; then
			is_system_disk=1
			break
		fi
	done
	[ "$is_system_disk" -eq 1 ] || disks+=("$candidate_disk")
done

if [ "${#disks[@]}" -eq 0 ]; then
	printf 'No eligible disks found. System disks are excluded: %s\n' "${system_disks[*]}" >&2
	exit 1
fi

printf 'Available non-system disks (system disks excluded: %s):\n' "${system_disks[*]}"
for index in "${!disks[@]}"; do
	printf '  %d) ' "$((index + 1))"
	lsblk -dno NAME,SIZE,MODEL "${disks[$index]}"
done

printf '\nSelect a disk by number: '
read -r choice
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#disks[@]}" ]; then
	printf 'Invalid selection.\n' >&2
	exit 1
fi

disk=${disks[$((choice - 1))]}

mounted=$(lsblk -nrpo MOUNTPOINT "$disk" | awk 'NF { print }')
if [ -n "$mounted" ]; then
	printf 'Refusing to format %s because it or one of its partitions is mounted:\n%s\n' "$disk" "$mounted" >&2
	exit 1
fi

printf '\nSelected device and current layout:\n'
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS "$disk"
printf '\nWARNING: every filesystem and partition on %s will be erased.\n' "$disk"
printf 'To continue, type the exact device path (%s): ' "$disk"
read -r confirmation
if [ "$confirmation" != "$disk" ]; then
	printf 'Cancelled.\n'
	exit 0
fi

printf 'Wiping filesystem signatures...\n'
sudo wipefs -a "$disk"

printf 'Zeroing the first 40 MiB...\n'
sudo dd if=/dev/zero of="$disk" bs=4M count=10 status=progress conv=fsync

printf 'Creating a GPT partition table and one ext4 partition...\n'
sudo parted "$disk" --script mklabel gpt
sudo parted "$disk" --script mkpart primary ext4 1MiB 100%
sudo partprobe "$disk"
command -v udevadm >/dev/null 2>&1 && sudo udevadm settle

case "$disk" in
*[0-9]) partition="${disk}p1" ;;
*) partition="${disk}1" ;;
esac

for _ in {1..20}; do
	[ -b "$partition" ] && break
	sleep 0.25
done
[ -b "$partition" ] || {
	printf 'Partition device did not appear: %s\n' "$partition" >&2
	exit 1
}

printf 'Formatting %s as ext4...\n' "$partition"
sudo mkfs.ext4 -L data "$partition"
printf '\nDone. Device is ready: %s\n' "$partition"
