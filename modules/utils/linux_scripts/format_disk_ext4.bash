#!/usr/bin/env bash

set -e

echo "Available disks:"
mapfile -t DISKS < <(lsblk -e7 -dpno NAME,SIZE,MODEL)

# Display numbered menu
i=1
for d in "${DISKS[@]}"; do
    echo "  $i) $d"
    ((i++))
done

echo
read -rp "Select a disk by number: " choice

# Validate selection
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#DISKS[@]}" ]; then
    echo "Invalid selection."
    exit 1
fi

# Extract just the device path (first field)
DISK=$(echo "${DISKS[$((choice-1))]}" | awk '{print $1}')

echo
echo "You selected: $DISK"
echo "WARNING: This will ERASE ALL DATA on $DISK"
read -rp "Type YES to continue: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo "Cancelled."
    exit 0
fi

echo "Wiping filesystem signatures..."
sudo wipefs -a "$DISK"

echo "Zeroing first few MB..."
sudo dd if=/dev/zero of="$DISK" bs=4M count=10 status=progress

echo "Creating GPT partition table..."
sudo parted "$DISK" --script mklabel gpt

echo "Creating ext4 primary partition..."
sudo parted "$DISK" --script mkpart primary ext4 1MiB 100%

echo "Refreshing kernel partition table..."
sudo partprobe "$DISK"

PART="${DISK}1"

echo "Formatting $PART as ext4..."
sudo mkfs.ext4 -L data "$PART"

echo
echo "Done!"
echo "Device is ready: $PART"
