#!/bin/bash

ppid=`ps -h -o ppid -p $$`
term=`ps -h -o comm -p $ppid`
if ! [[ $term =~ ^gnome-terminal ]]; then
	gnome-terminal -- /bin/bash "$0"
	exit
fi

TEN_MIN=$(( 10 * 60 ))
SECONDS=${1:-$TEN_MIN}

reverse_video () { printf '\e[?5h'; VID=1; }
normal_video () { printf '\e[?5l'; VID=; }

start=`date +%s`

printf "%d %2d %2d %2d\t%d\n" 5 10 20 60 delta
tput sc
for i in `seq $SECONDS`; do
	read -n 1 -t 0.01 INPUT
	if [[ $INPUT =~ q|Q ]]; then
		break
	fi
	now=`date +%s`
	delta=$(( $now - $start ))
	mod5=$(( $delta % 5 ))
	mod10=$(( $delta % 10 ))
	mod20=$(( $delta % 20 ))
	mod60=$(( $delta % 60 ))
	tput rc
	printf "%d %2d %2d %2d\t%d" $mod5 $mod10 $mod20 $mod60 $delta
	tput bel
	if [[ $VID == 1 ]]; then
		normal_video
	else
		reverse_video
	fi
	sleep 1
done
