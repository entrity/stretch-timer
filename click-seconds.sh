#!/bin/bash

# Click+flash terminal each second

# Usage:
# ./$0 [seconds]

# If the param is empty, click is indefinite; otherwise it clicks for param
# seconds.

# catch sig and go to normal

# Don't change the system volume in these scripts. If you want the bell
# quieter, go to the os settings > Sound > System Sounds (which I think only
# handles alerts/bells).

get_now () { date +%s; }

expiration_reached () {
	[[ -n "$STOP_TIME" ]] && [[ $STOP_TIME -le $(get_now) ]]
}

make_click_sound () { tput bel; }
reversed_video () { printf '\e[?5h'; VID=1; }
normal_video () { printf '\e[?5l'; VID=; }

invert_video () {
	if ((VID)); then
		normal_video
	else
		reversed_video
	fi
}

# Print MM:SS
print_formatted_seconds () {
	local delta=$1
	sec=$(( delta % 60 ))
	min=$(( delta / 60 ))
	printf "%2d:%02d" $min $sec
}

# Print MM:SS / MM:SS ( S / S )
print_formatted_count () {
	print_formatted_seconds $1
	printf " / %s ( %d / %d )" $QUOTA_FORMATTED_SECONDS $1 $QUOTA_SECONDS
}

# Call print_formatted_count with the current time
show_count () {
	local NOW=$(get_now)
	local DELTA=$(( NOW - START_SECONDS ))
	tput rc
	print_formatted_count $DELTA
}

cleanup () {
	if ((VID)); then
		normal_video # End with normal video
	fi
	echo
}

on_sigint () {
	cleanup
	kill $PPID
	kill $$
}

trap on_sigint SIGINT

START_SECONDS=$(get_now)
QUOTA_SECONDS=$1
QUOTA_FORMATTED_SECONDS=`print_formatted_seconds $QUOTA_SECONDS`
if [[ -n $QUOTA_SECONDS ]]; then
	STOP_TIME=$(( START_SECONDS + QUOTA_SECONDS ))
else
	STOP_TIME=
fi

tput sc

# Loop
while ((1)); do
	if expiration_reached; then break; fi
	show_count
	(($DOCLICK)) && make_click_sound
	(($DOBLINK)) && invert_video
	# Instead of sleep for 1 sec, spend 1 sec listening for keyboard input
	read -s -N1 -t1 KBD_INPUT
	# Allow user to hit 'Enter' to break the loop and start stretches
	if [[ $KBD_INPUT == $'\x0a' ]]; then
		cleanup && exit
	elif [[ $KBD_INPUT == m ]]; then
		DOCLICK=$(( 1 - ${DOCLICK:-0} ))
	elif [[ $KBD_INPUT == b ]]; then
		DOBLINK=$(( 1 - ${DOBLINK:-0} ))
	fi
done

cleanup
