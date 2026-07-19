#!/bin/bash
john_zip_file() {
	rm -f $HOME/.john/john.rec
	cd "$(pwd)" || exit 1
	hash=/tmp/"$RANDOM"
	zip2john "$1" >"$hash"
	john "$hash" --wordlist=/usr/share/john/password.lst --stdout | head -n10
	rm -f "$hash"
}
export john_zip_file
