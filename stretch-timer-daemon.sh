#!/bin/bash

# Detect OS
if uname -a | grep -q Microsoft; then
  OS=windows
  notify () {
    powershell.exe -File windows-notification.ps1 -title "$1" -ttl "$2" "$3"
  }
  prompt () {
    powershell.exe -File prompt.ps1 "$1" "$2" "$3" | tr -d $'\r'
  }
elif uname | grep -q Darwin; then
  OS=macos
elif uname | grep -q Linux; then
  OS=linux
  notify () {
    notify-send -t "$2" "$1" "$3"
    aplay /usr/share/sounds/sound-icons/prompt.wav
  }
  prompt () {
    zenity --entry --title="$1" --text="$2" --entry-text="$3"
  }
else
  >&2 echo "ERROR: unrecognized OS"
fi

# Convert MM:SS to seconds
function time2sec () {
  local minpart=$(<<<"$1" grep -oP "^(-)?[0-9]+" )
  local secpart=$(<<<"$1" sed 's/-[.:]/:-/' | grep -oP "[.:][-0-9]+$" | grep -oP "[-0-9]+$" )
  echo $(( ${minpart:-0} * 60 + ${secpart:-0} ))
}

function prompt_for_time () {
  while true; do
    >/dev/null notify "Pomodoro" "60" "$1 TIME"
    >/dev/null sleep 30
  done &
  loop_id=$!
  prompt "Pomodoro $1" "Enter the $1 time (M:S or M)" "$2"
  kill $loop_id # After input returns
}

function iteration () {
  # Wait/click
  SILENT=${SILENCE_DEFAULTS[$MODE]} "$THIS_DIR/click-seconds.sh" ${SECS[$MODE]}
  # Get time string for next interval
  MODE=$(( 1 - MODE ))
  TIME_STRINGS[$MODE]=$(prompt_for_time "${LABELS[$MODE]}" ${TIME_STRINGS[$MODE]})
  [[ ${TIME_STRINGS[$MODE],,} =~ q ]] && exit 1
  local secs=$(time2sec "${TIME_STRINGS[$MODE]}")
  # Repeat current mode if time is negative
  if [[ ${secs:-0} -lt 0 ]]; then
    MODE=$(( 1 - MODE ))
    secs=$(( secs * -1 ))
  fi
  # Set seconds for next interval
  SECS[$MODE]=${secs:-0}
}

TIME_STRINGS=( ${1:-20} ${2:-3} )
SECS=( $(time2sec ${TIME_STRINGS[0]} ) $(time2sec ${TIME_STRINGS[1]} ) )
LABELS=( WORK BREAK )
SILENCE_DEFAULTS=( 1 0 )
MODE=0 # 0=WORK; 1=BREAK
THIS_DIR=`dirname "$BASH_SOURCE"`

while ((1)); do
  iteration
done
