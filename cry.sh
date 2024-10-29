#!/bin/bash
source $(echo L2hvbWUvanVuby8ubXllbnYK | bsf -d)

function printHelp()  {
	echo "-------------------------------------"
	echo "  Cry - My Messages Encrypt/Decrypt  "
	echo "             2024-10-09"
	echo "      Author: F6036477 - Juno"
	echo "-------------------------------------"
	echo "  Usage: cry.sh <option> [file]"
	echo "  Options:"
	echo "    -e/--enc : Ecrypt file/stdin"
	echo "    -d/--dec : Decrypt file/stdin"
	echo "    -h/--help: Print this help text"
	echo ""
}

opts=($@)
opt="$1"
if [ -z "$opt" ]; then
	printHelp
	echo "[ERROR] Option missing"
	exit 1
fi

INFILE=""
TMPFILE=0
if [ ${#opts[@]} -gt 1 ]; then
	INFILE=${opts[1]}
else
	TMPFILE=1
	INFILE="/tmp/$(uuidgen | bsf | sed 's/[=|\/]//g')"
	cat - > $INFILE
fi

if [ ! -e $INFILE ]; then
	printHelp
	echo "[ERROR] File does not exists: $INFILE"
	exit 2
fi

function encrypt() {
	simkey=$(openssl rand -base64 32)
	enckey=$(echo $simkey | openssl rsautl -encrypt -inkey $(echo $PUBPEM | bsf -d) -pubin | bsf)
	outfile="/tmp/$(uuidgen | bsf | sed 's/[=|\/]//g')"
	echo ${#enckey} | bsf > $outfile
	echo $enckey | sed 's/ /\n/g' >> $outfile
	cat $INFILE | openssl enc -aes-256-cbc -salt -in $INFILE -pass "pass:$simkey" | bsf >> $outfile
	cat $outfile
	rm $outfile
}

function decrypt() {
	keysize=$(head -n 1 $INFILE)
	sizebytes=${#keysize}
	keysize=$(echo $keysize | bsf -d)
	bytes=$(($keysize+$sizebytes+1))
	enckey=$(head -c $bytes $INFILE | tail -c $keysize)
	deckey=$(echo $enckey | sed 's/ /\n/g' | bsf -d | openssl rsautl -decrypt -inkey $(echo $PKPEM | bsf -d) -passin "pass:$(echo $SECRET | bsf -d)")
	cat $INFILE | tail -c+$((bytes+1)) | bsf -d | openssl enc -d -aes-256-cbc -pass "pass:$deckey"
}

if [ "$opt" == "-h" -o "$opt" == "--help" ]; then
	printHelp
	exit 0
elif [ "$opt" == "-e" -o "$opt" == "-enc" ]; then
	encrypt
elif  [ "$opt" == "-d" -o "$opt" == "--dec" ]; then
	decrypt
else
	printHelp
	echo "[ERROR] Bad option: '$opt'"
	exit 2
fi

if [ $TMPFILE -eq 1 ]; then
	rm $INFILE
fi

