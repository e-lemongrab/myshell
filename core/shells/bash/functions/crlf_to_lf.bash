#!/bin/bash
crlf_to_lf() {
	sub_dir=/tmp/"$RANDOM"
	# la seguent comanda no treballa amb directoris/arxius ocults
	find ./ -type d -not -path '*/.*' 1>"$sub_dir"
	for relative_path in content=$(cat "$sub_dir"); do
		#file=$(ls -lah --color "$relative_path" 2> /dev/null | awk '{ printf $9"\n"}' | awk 'NR>3')
		#echo -e "\nRelative path: $relative_path""\n$file"
		find "$relative_path" \
			-type f ! \( -name '*.jar' -o -name '*.zip' -o -name '*.dll' -o -name '*.ps1' -o -name '*.psm1' -o -name '*.kdbx' -o -name '*.png' \) \
			-exec dos2unix {} {} \;
	done
	rm -f "$sub_dir"
}
export crlf_to_lf
