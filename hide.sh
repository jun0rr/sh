#!/bin/bash

# Align text to center, adding {2} <char> to left and right until {1} line size.
# {1} Line size
# {2} Padding char
# {3} Text
function padCenter() {
        lineSize=$1
        char="$2"
        text="$3"
        textLen=${#text}
        size=$(($lineSize-$textLen))
        sizeL=$(($size/2))
        sizeR=$sizeL
        if [ $(($sizeL*2)) -lt $size ]; then
                sizeR=$(($sizeL+1))
        fi
        for ((i=0; i<sizeL; i++)); do
                echo -n "$char"
        done
        echo -n "$text"
        for ((i=0; i<sizeR; i++)); do
                echo -n "$char"
        done
        echo ""
}


# Align text to right, adding {2} <char> to left until {1} line size.
# {1} Line size
# {2} Padding char
# {3} Text
function padLeft() {
        lineSize=$1
        char="$2"
        text="$3"
        textLen=${#text}
        size=$(($lineSize-$textLen))
        for ((i=0; i<size; i++)); do
                echo -n "$char"
        done
        echo "$text"
}


VERSION="202411.03"

function printHelp() {
	padCenter 38 '-'
	padCenter 38 ' ' 'HideSH - Bash Script Obfuscation'
	padCenter 38 ' ' "Version: $VERSION"
	padCenter 38 ' ' 'Author: F6036477 - Juno'
	padCenter 38 '-'
	line="Usage: hide.sh [-n <num>] [-e] [-s] [-o <file>] [input]"
        padLeft $((${#line}+2)) ' ' "$line"
	line="When [input] is not provided, content is readed from stdin"
        padLeft $((${#line}+4)) ' ' "$line"
	line="Options:"
        padLeft $((${#line}+2)) ' ' "$line"
        line="-n/--num .......: Number of iterations (default=1)"
        padLeft $((${#line}+4)) ' ' "$line"
        line="-e/--encrypt ...: Encrypt input script with random password"
        padLeft $((${#line}+4)) ' ' "$line"
        line="-s/--src .......: Source input script instead of executing"
        padLeft $((${#line}+4)) ' ' "$line"
        line="-o/--out .......: Output file (default stdout)"
        padLeft $((${#line}+4)) ' ' "$line"
        line="-h/--help ......: Print this help text"
        padLeft $((${#line}+4)) ' ' "$line"
        line="-v/--version ...: Print version"
        padLeft $((${#line}+4)) ' ' "$line"
	echo ""
}


opts=($@)
olen=${#opts[@]}
OPTN=0
ARGN=1
OPTO=0
ARGO=""
OPTS=0
OPTE=0
INPUT=""


for ((i=0; i<olen; i++)); do
	opt=${opts[i]}
        case $opt in
                -n | --num)
                        OPTN=1
                        if [ $i -ge $((${#opts[@]}-1)) ]; then
                                printHelp
                                echo "[ERROR] Number of iterations (-n) missing"
                                exit 1
                        fi
                        i=$((i+1))
                        ARGN=${opts[$i]}
                        ;;
                -e | --enncrypt)
                        OPTE=1
                        ;;
                -s | --src)
                        OPTS=1
                        ;;
                -o | --out)
                        OPTO=1
                        if [ $i -ge $((${#opts[@]}-1)) ]; then
                                printHelp
                                echo "[ERROR] Output file (-o) not found"
                                exit 2
                        fi
                        i=$((i+1))
                        ARGO=${opts[$i]}
                        ;;
                -h | --help)
                        printHelp
                        exit 0
                        ;;
                -v | --version)
                        echo "HideSH Version: $VERSION"
                        exit 0
                        ;;
                *)
			if [[ $opt =~ ^\-[a-z]$ || $opt =~ ^\-\-[a-z]+$ ]]; then
				printHelp
				echo "[ERROR] Unknown option: $opt"
				exit 3
			elif [ -z "$INPUT" ]; then
				INPUT="$opt"
			else
				INPUT="$INPUT $opt"
			fi
                        ;;
        esac
done

out='df=/tmp/$(uuidgen | base64 | sed "s/[=|\/|\+]//g");'
c=""
if [ -e "$INPUT" ]; then
	c=$(cat $INPUT | gzip | base64 | tr '\n' ' ' | sed -r 's/\s$//g')
elif [ ! -z "$INPUT" ]; then
	c=$(echo $INPUT | gzip | base64 | tr '\n' ' ' | sed -r 's/\s$//g')
else
	c=$(timeout 3s cat -)
	if [ -z "$c" ]; then
		printHelp
		echo "[ERROR] Nothig readed from stdin"
		exit 4
	fi
	c=$(echo $c | gzip | base64 | tr '\n' ' ' | sed -r 's/\s$//g')
fi

if [ $OPTE -eq 1 ]; then
	pname=$(openssl rand -base64 8 | sed 's/[=|\/|\+]//g')
	pname='p'$pname
	pass=$(openssl rand -base64 32 | sed 's/[=|\/|\+]//g')
	epass=$(echo "$pname=$pass;" | gzip | base64 | tr '\n' ' ' | sed -r 's/\s$//g')
	out=$out'eval $(echo "'$epass'" | sed "s/ /\n/g" | base64 -d | gzip -d);'
	c=$(echo "$c" | openssl enc -aes-256-cbc -salt -pass "pass:$pass" | base64 | tr '\n' ' ' | sed -r 's/\s$//g')
	out=$out'echo "'$c'" | sed "s/ /\n/g" | base64 -d | openssl enc -d -aes-256-cbc -pass "pass:$'$pname'" | sed "s/ /\n/g" | base64 -d | gzip -d > $df;'
else
	out=$out'echo "'$c'" | sed "s/ /\n/g" | base64 -d | gzip -d > $df;'
fi

out=$out'chmod +x $df;'
if [ $OPTS -eq 1 ]; then
	out=$out'source $df;'
else
	out=$out'$df $@;'
fi
out=$out'rm $df'
for ((i=0; i<ARGN; i++)); do
        out=$(echo "$out" | gzip | base64 | tr '\n' ' ' | sed -r 's/\s$//g')
        out=$(echo 'eval $(echo "'$out'" | sed "s/ /\n/g" | base64 -d | gzip -d)')
done

if [ $OPTO -eq 1 ]; then
	echo '#!/bin/bash' > $ARGO
	echo $out >> $ARGO
else
	echo $out
fi

