#!/bin/bash
script_path=$(dirname $0)
source "$script_path/functions.bash"
#Main
echo -e "1) Check if leaked - password\n"
echo -e "2) Check if leaked - hash\n"
echo -e "Select number:\n"
read number
case "$number" in
"1")
	leaked_password
	;;
"2")
	leaked_hash
	;;
*)
	echo "No valid"
	;;
esac
