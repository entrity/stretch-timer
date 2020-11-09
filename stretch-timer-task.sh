#!/bin/bash

THISDIR=$(dirname "$0")
PROMPT_TIMEOUT=30 # `read` timeout
WAIT_TIMEOUT=240 # auto-snooze after `read` timeout

KEEP_LOOPING=1

is_screensaver_active () {
  gdbus call -e -o /org/gnome/ScreenSaver -d org.gnome.ScreenSaver -m org.gnome.ScreenSaver.GetActive | grep -s true
}
snooze () {
	local MINUTES=$1
	local DEADLINE=$(( $(date +%s) + ($MINUTES * 60) ))
	echo
	tput sc
	while [[ $(date +%s) -lt $DEADLINE ]]; do
		local DELTA=$(( $DEADLINE - $(date +%s) ))
		clear; printf "Snoozing $(date -u -d @${DELTA} +%H:%M:%S)... (press Enter to end)"
		read -t 1 -N 1 KBD_IN # Wait 1 second (or until user input)
		if [[ $KBD_IN == $'\x0a' ]]; then # <Enter>
			start
			return
		elif [[ $KBD_IN =~ q|Q ]]; then # <q>
			exit
		fi
	done
	echo -e "\nSnooze done"
}
click_seconds () { SKIP_TERM_CHECK=1 bash "$THISDIR/click-seconds.sh"; }
clear () { tput rc; tput ed; }
reverse_video () { printf '\e[?5h'; }
normal_video () { printf '\e[?5l'; }
activate () { xdotool search --name 'Stretch Break' windowactivate; }
flash () {
	REP=${1:-6} # How many times to flash
	SEC=${2:-0.1} # How many seconds to wait between flashes
	DOBEL=${3:-1} # Whether to sound the bell
	for i in `seq $REP`; do
		(($DOBEL)) && tput bel
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
	# Spinlock if screensaver active
  is_screensaver_active && echo "The screensaver was active"
  while is_screensaver_active; do
    sleep 60
  done
	# Run
	flash 4 0.1 0
	echo -e -n "Stretch break.\a "
	read -n 999999 -s -t 0.01 DISCARD
	read -n 1 -s -p "Press any key: " -t $PROMPT_TIMEOUT OPT
	read -n 999999 -s -t 0.01 DISCARD
	if [[ -n $OPT ]]; then
		case $OPT in
			[123456789]) snooze $OPT;;
			c) click_seconds;;
			q) KEEP_LOOPING=0;;
			*) start;;
		esac
	else
		KEEP_LOOPING=1
	fi
}

activate
flash 1 0.1 0
while (($KEEP_LOOPING)); do
	mainmenu
done
echo END
