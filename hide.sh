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


VERSION="202411.05"

function printHelp() {
	padCenter 38 '-'
	padCenter 38 ' ' 'HideSH - Bash Script Obfuscation'
	padCenter 38 ' ' "Version: $VERSION"
	padCenter 38 ' ' 'Author: F6036477 - Juno'
	padCenter 38 '-'
	line="Usage: hide.sh [-h] [-o <file>] (-u | [-n <num>] [-e] [-s]) [input]"
        padLeft $((${#line}+2)) ' ' "$line"
	line="When [input] is not provided, content is readed from stdin"
        padLeft $((${#line}+4)) ' ' "$line"
	line="Options:"
        padLeft $((${#line}+2)) ' ' "$line"
        line="-e/--encrypt ...: Encrypt input script with random password"
        padLeft $((${#line}+4)) ' ' "$line"
        line="-h/--help ......: Print this help text"
        padLeft $((${#line}+4)) ' ' "$line"
        line="-n/--num .......: Number of iterations (default=1)"
        padLeft $((${#line}+4)) ' ' "$line"
        line="-o/--out .......: Output file (default stdout)"
        padLeft $((${#line}+4)) ' ' "$line"
        line="-s/--src .......: Call 'source' on script instead of executing"
        padLeft $((${#line}+4)) ' ' "$line"
        line="-u/--unhide ....: Unhide obfuscated content"
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
OPTU=0
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
                -e | --encrypt)
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
                -u | --unhide)
                        OPTU=1
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

if [ $OPTU -eq 1 -a $((OPTN+OPTS+OPTE)) -gt 0 ]; then
	printHelp
	echo "[ERROR] Option -u/--unhide can not be used with -n|-s|-e"
	exit 4
fi

function parseInput() {
        if [ -e "$INPUT" ]; then
                c=$(cat $INPUT | sed ':a;N;$!ba;s/\n/_NL_/g')
        elif [ ! -z "$INPUT" ]; then
                c=$(echo "$INPUT" | sed ':a;N;$!ba;s/\n/_NL_/g')
        else
                c=$(timeout 3s cat - | sed ':a;N;$!ba;s/\n/_NL_/g')
                if [ -z "$c" ]; then
                        printHelp
                        echo "[ERROR] Nothig readed from stdin"
                        exit 4
                fi
        fi
}

function encodeInput() {
	parseInput
	if [[ ! $c =~ ^#!/.* ]]; then
		c='#!/bin/bash_NL_'$c
	fi
	c=$(echo $c | sed 's/_NL_/\n/g' | gzip | base64 | tr '\n' ' ' | sed -r 's/\s$//g')
}

function encryptInput() {
        pname=$(openssl rand -base64 8 | sed 's/[=|\/|\+]//g')
        pname='p'$pname
        pass=$(openssl rand -base64 32 | sed 's/[=|\/|\+]//g')
        epass=$(echo "$pname=$pass" | gzip | base64 | tr '\n' ' ' | sed -r 's/\s$//g')
        out=$out'eval $(echo "'$epass'" | sed "s/ /\n/g" | base64 -d | gzip -d);'
        c=$(echo "$c" | openssl enc -aes-256-cbc -pbkdf2 -salt -pass "pass:$pass" | base64 | tr '\n' ' ' | sed -r 's/\s$//g')
        out=$out'echo "'$c'" | sed "s/ /\n/g" | base64 -d | openssl enc -d -aes-256-cbc -pbkdf2 -pass "pass:$'$pname'" | sed "s/ /\n/g" | base64 -d | gzip -d > $df;'
}

function formatOutput() {
	out=$out'chmod +x $df;'
	#out=$out'echo "------ $df ------"; cat $df; echo "------ $df ------";'
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
}

function decodeInput() {
	parseInput
	if [[ ! $c =~ ^eval.* && ! $c =~ ^#!/.+_NL_eval.* ]]; then
		printHelp
		echo "[ERROR] Input is not obfuscated"
		exit 5
	fi
	c=$(echo "$c" | sed -E 's|^#!/.+_NL_||g')
	while [[ $c =~ ^eval.+ ]]; do
		c=$(echo $c | sed 's/eval $(echo "//g' | sed 's/".*//g')
		c=$(echo $c | sed "s/ /\n/g" | base64 -d | gzip -d)
	done
	# if is encrypted
	if [[ $c =~ .*pass:$p.{8,11}.* ]]; then
		# get password
		pass=$(echo $c | sed -E 's/df=.*\$\(echo "//g' | sed -E 's|^([A-Za-z0-9/+=]{76}\s[A-Za-z0-9/+=]{15,28}).*|\1|' | sed "s/ /\n/g" | base64 -d | gzip -d | sed -E 's/^p.{8,11}=//g')
		# get encrypted content
		c=$(echo $c | sed 's/^.*);echo //g' | sed -E 's|^("[A-Za-z0-9/+=]+(\s[A-Za-z0-9/+=]+)+").*|\1|' | sed 's/"//g')
		# decrypt content
		c=$(echo $c | sed "s/ /\n/g" | base64 -d | openssl enc -d -aes-256-cbc -pbkdf2 -pass "pass:$pass" | sed "s/ /\n/g" | base64 -d | gzip -d | sed ':a;N;$!ba;s/\n/_NL_/g')
	else
		c=$(echo $c | sed -E 's|^.+("[A-Za-z0-9/+=]+(\s[A-Za-z0-9/+=]+)+").*|\1|' | sed 's/"//g' | sed "s/ /\n/g" | base64 -d | gzip -d | sed ':a;N;$!ba;s/\n/_NL_/g')
	fi
	out="$c"
}

out='df=/tmp/$(uuidgen | sed "s/-//g");'
c=""

if [ $OPTU -eq 1 ]; then
	decodeInput
else
	encodeInput
	if [ $OPTE -eq 1 ]; then
		encryptInput
	else
		out=$out'echo "'$c'" | sed "s/ /\n/g" | base64 -d | gzip -d > $df;'
	fi
	formatOutput
fi

if [ $OPTO -eq 1 ]; then
	echo -n "" > $ARGO
	if [[ ! $out =~ ^#!/.+ ]]; then
		echo '#!/bin/bash' >> $ARGO
	fi
	echo $out | sed 's/_NL_/\n/g' >> $ARGO
else
	echo $out | sed 's/_NL_/\n/g'
fi

