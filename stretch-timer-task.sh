#!/bin/bash

PROMPT_TIMEOUT=30 # `read` timeout
WAIT_TIMEOUT=240 # auto-snooze after `read` timeout

KEEP_LOOPING=1

snooze () {
	if (($#)); then
		MINUTES=$1
	else
		read -t $PROMPT_TIMEOUT -p "Enter number of minutes: " MINUTES
	fi
	if [[ -z $MINUTES ]]; then
		sleep $WAIT_TIMEOUT
		KEEP_LOOPING=1
	else
		echo -e "\n$MINUTES minutes snooze..."
		tput sc
		while [[ $MINUTES -gt 0 ]]; do
			clear
			printf "Snoozing $MINUTES minutes..."
			sleep 60
			MINUTES=$(( $MINUTES - 1 ))
		done
		echo -e "\nSnooze done"
	fi
}
clear () { tput rc; tput ed; }
reverse_video () { printf '\e[?5h'; }
normal_video () { printf '\e[?5l'; }
activate () { xdotool search --name 'Stretch Break' windowactivate; }
flash () {
	REP=${1:-6}
	SEC=${2:-0.1}
	for i in `seq $REP`; do
		tput bel
		reverse_video
		sleep $SEC
		normal_video
		sleep $SEC
	done
}
start () {
	for rep in `seq 5`; do
	  flash 3 0.5 # wait seconds before next rep
	  sec=0
	  clear
	  printf "$rep : $sec"
	  for sec in `seq 5`; do
	    sleep 1
	    clear
	    printf "$rep : $sec"
	  done
	done
	echo
}

mainmenu () {
	activate
	flash 4
	echo -e "Stretch break\a"
	read -n 999999 -s -t 0.01 DISCARD
	read -n 1 -s -p "Press any key: " -t $PROMPT_TIMEOUT OPT
	read -n 999999 -s -t 0.01 DISCARD
	if [[ -n $OPT ]]; then
		case $OPT in
			[123456789]) snooze $OPT;;
			s) snooze;;
			q) KEEP_LOOPING=0;;
			*) start;;
		esac
	else
		KEEP_LOOPING=1
	fi
}

activate
flash 1
while (($KEEP_LOOPING)); do
	mainmenu
done
echo END
