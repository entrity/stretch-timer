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
is_screensaver_active () {
  gdbus call -e -o /org/gnome/ScreenSaver -d org.gnome.ScreenSaver -m org.gnome.ScreenSaver.GetActive | grep -s true
}
mainloop () {
	while ((1)); do
    tput sc
    DUE=$(( $(now) + (20 * 60) ))
    while [[ $(now) -lt $DUE ]]; do
      if [[ -t 1 ]]; then # If fd 1 is a terminal
        tput cr; tput ed;
        REMAINING=$(( $DUE - $(now) ))
        printf "Remaining: %s" "$(date -d@$REMAINING -u +%H:%M:%S)"
      fi
      # Allow user to hit 'Enter' to break the loop and start stretches
      read -s -N1 -t1 KBD_INPUT
      if [[ $KBD_INPUT == $'\x0a' ]]; then
        break
      fi
    done
    # Spinlock if screensaver is active
    tput cr; tput ed;
    is_screensaver_active && echo "The screensaver was active"
    while is_screensaver_active; do
      sleep 60
    done
    # Start stretches interface
		iteration
	done
}
mainloop
