#!/bin/bash
# Navigate to the parent directory containing all the repos
# Create an empty array to hold the names of the directories
changed_dirs=()
# Loop through each directory
for dir in */; do
	if [ -d "$dir/.git" ]; then
		cd "$dir" || continue
		git reset --hard
		# git checkout develop  # Checkout the develop branch
		# git pull              # Pull the latest changes
		changed_dirs+=("$dir") # Add the directory to the array
		cd ..
	fi
done
# Print the list of directories where changes were undone
echo "Changes have been undone in the following directories:"
printf '%s\n' "${changed_dirs[@]}"
