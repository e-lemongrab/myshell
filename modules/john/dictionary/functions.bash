#!/bin/bash
leaked_password() {
	echo "Insert Password"
	read plain_text
	raw_hash=/tmp/"$RANDOM"
	hash=/tmp/"$RANDOM"
	echo -n "$plain_text" | openssl md5 >$raw_hash
  cat "$raw_hash" | awk '{ printf $2 }' >"$hash"
	rm -f $raw_hash
  echo -e "Looking for: $(cat "$hash")"
  john "$hash" --wordlist=/usr/share/john/password.lst --format=Raw-MD5 --stdout | head -n10
  rm -f "$hash"
	plain_text=""
}
leaked_hash() {
	echo "Wanna set format? [y/n]"
	read answer
	if [ "$answer" = "y" ]; then
		john --list=formats
		echo "Select format"
		read format
		echo "Insert hash"
		read check_hash
		hash=/tmp/"$RANDOM"
		echo -n "$check_hash" >$hash
		#john --show $raw_hash
		john --stdout $hash --wordlist=/usr/share/john/password.lst --format=$format
		rm -f $hash
		check_hash=""
	else
		echo "Insert hash"
		read check_hash
		hash=/tmp/"$RANDOM"
		echo -n "$check_hash" >$hash
		#john --show $raw_hash
		john $hash --wordlist=/usr/share/john/password.lst
		rm -f $hash
		check_hash=""
	fi
}
  rm -rf "$HOME/.john/john.rec"
  export leaked_password
  export leaked_hash
