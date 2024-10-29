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


# Align text to left, adding {2} <char> to right until {1} line size.
# {1} Line size
# {2} Padding char
# {3} Text
function padRight() {
        lineSize=$1
        char="$2"
        text="$3"
        textLen=${#text}
        size=$(($lineSize-$textLen))
	echo -n "$text"
	for ((i=0; i<size; i++)); do
		echo -n "$char"
	done
	echo ""
}


# Justify text to the line size, adding {2} <char> between words if necessary.
# {1} Line size
# {2} Padding char
# {3} Text
function justify() {
        lineSize=$1
        char="$2"
        text="$3"
        textLen=${#text}
        size=$(($lineSize-$textLen))
	words=($text)
	wlen=$((${#words[@]}-1))
	sizeL=$(($lineSize-$textLen+$wlen))
	sp=$(($sizeL/$wlen))
	for ((i=0; i<wlen; i++)); do
		echo -n ${words[$i]}
		for ((j=0; j<$sp; j++)); do
			echo -n "$char"
		done
		if [ $i -eq $(($wlen-1)) -a $(($sp*$wlen)) -lt $sizeL ]; then
			echo -n "$char"
		fi
	done
	echo "${words[$wlen]}"
}

