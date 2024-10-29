#!/bin/bash
input=$1
n=1
if [[ $input =~ ^[0-9]+$ ]]; then
        n=$input
        input=$2
fi
if [ ! -e $input ]; then
        echo "[ERROR] File does not exists: $file"
        exit 1
fi
out='df=/tmp/$(uuidgen | base64 | sed "s/[=|\/]//g");'
c=$(cat $input | base64 | tr '\n' ' ' | sed -r 's/\s$//g')
out=$out'echo "'$c'" | sed "s/ /\n/g" | base64 -d > $df;'
out=$out'chmod +x $df;'
out=$out'$df;'
out=$out'rm $df'
for ((i=0; i<n; i++)); do
        out=$(echo "$out" | base64 | tr '\n' ' ')
        out=$(echo 'eval $(echo "'$out'" | sed "s/ /\n/g" | base64 -d)')
done
echo $out
