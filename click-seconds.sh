#!/bin/bash

# Click+flash terminal each second

# Usage:
# ./$0 [seconds]

# If the param is empty, click is indefinite; otherwise it clicks for param
# seconds.

# catch sig and go to normal

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

show_count () {
	local NOW=$(get_now)
	local DELTA=$(( NOW - START_SECONDS ))
	tput rc
	printf "%d" $DELTA
}

cleanup () {
	if ((VID)); then
		normal_video # End with normal video
	fi
	echo
	exit
}

trap cleanup SIGINT

START_SECONDS=$(get_now)
QUOTA_SECONDS=$1
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
	make_click_sound
	invert_video
	sleep 1
done

cleanup
