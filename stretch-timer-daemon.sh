#!/bin/bash

CURDIR=$(dirname $(readlink -f $0))

not_nohup () {
	[[ $(readlink -f /proc/$$/fd/1) =~ /dev/pts ]]
}
terminate () {
	ps -C $0 | xargs kill
}
iteration () {
	gnome-terminal --wait --title="Stretch Break" -- /bin/bash $CURDIR/stretch-timer-task.sh
}
now () {
  date +%s
}
mainloop () {
	while ((1)); do
    tput sc
    DUE=$(( $(now) + (20 * 60) ))
    while [[ $(now) -lt $DUE ]]; do
      if [[ -t 1 ]]; then
        tput rc; tput ed;
        REMAINING=$(( $DUE - $(now) ))
        printf "Remaining: %s" "$(date -d@$REMAINING -u +%H:%M:%S)"
      fi
      sleep 1
    done
		iteration
	done
}
mainloop
