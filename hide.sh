#!/bin/bash
input=$1
n=1
if [[ $input =~ [0-9]+ ]]; then
	n=$input
	input=$2
fi
if [ ! -e $input ]; then
	echo "[ERROR] File does not exists: $file"
	exit 1
fi
c=$(cat $input | sed -r 's/^#.+$//g' | tr '\n' ';' | sed -r 's/;+/;/g'  | sed -r 's/then;+/then /g' | sed -r 's/do;+/do /g' | sed -r 's/;$//g' | sed -r 's/^;//g' | sed -r 's/\s+/ /g')
for ((i=0; i<n; i++)); do
	c=$(echo "$c" | base64 | tr '\n' ' ')
	c=$(echo 'eval $(echo "'$c'" | sed "s/ /\n/g" | base64 -d)')
done
echo $c
