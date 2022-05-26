#!/bin/bash

set -uo pipefail

cd "$(dirname "$BASH_SOURCE")"

# Detect OS
if uname -a | grep -q Microsoft; then
  OS=windows
  remind () {
    powershell.exe -File windows-notification.ps1 -title "$1" -ttl "$2" "$3"
  }
  prompt () {
    powershell.exe -File prompt.ps1 "$1" "$2" "$3" | tr -d $'\r'
  }
elif uname | grep -q Darwin; then
  OS=macos
elif uname | grep -q Linux; then
  OS=linux
  remind () {
    wmctrl -a "$1"
    ffplay -nodisp -autoexit -volume 20 /usr/share/sounds/sound-icons/prompt.wav 2>/dev/null
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
  local TITLE="Pomodoro $1"
  while true; do
    >/dev/null sleep 30
    >/dev/null remind "$TITLE" "60" "$1 TIME"
  done &
  loop_id=$!
  prompt "$TITLE" "Enter the $1 time (M:S or M)" "$2"
  local ret=$?
  kill $loop_id # After input returns
  return $ret
}

function wait_seconds () {
  SILENT=$(( 1 - DO_CLICK )) \
  NOBLINK=$(( 1 - DO_BLINK )) \
  "$THIS_DIR/click-seconds.sh" "${1}"
}

function iteration () {
  # Increment
  MODE=$(( 1 - MODE ))
  # Get user input for next interval's time string
  USER_INPUT=$(prompt_for_time "${LABELS[$MODE]}" ${TIME_STRINGS[$MODE]} | tr -d ' ')
  if (($?)); then
    return 1
  elif [[ ${USER_INPUT,,} =~ q ]]; then
    exit 1
  elif [[ -n $USER_INPUT ]]; then
    TIME_STRINGS[$MODE]=${USER_INPUT}
  else
    TIME_STRINGS[$MODE]=${DEFAULT_TIME_STRINGS[$MODE]}
  fi
  # Calculate seconds (and mode) for current interval
  local secs=$(time2sec ${TIME_STRINGS[$MODE]})
  if [[ ${secs:-0} -lt 0 ]]; then
    MODE=$(( 1 - MODE ))
    secs=$(( secs * -1 ))
  fi
  # Wait & click/blink
  wait_seconds "${secs}"
}

# Define defaults, which can be overriden by config file or args
DEFAULT_WORK_MIN=${1:-20}
DEFAULT_BREAK_MIN=${2:-.30}
DO_BLINK=1
DO_CLICK=1
if [[ -f $HOME/.config/stretch-timer.conf ]]; then
  . $HOME/.config/stretch-timer.conf
fi

# Organize data structures
DEFAULT_TIME_STRINGS=( ${DEFAULT_WORK_MIN} ${DEFAULT_BREAK_MIN} )
TIME_STRINGS=( ${DEFAULT_WORK_MIN} ${DEFAULT_BREAK_MIN} )
LABELS=( WORK BREAK )
SILENCE_DEFAULTS=( 1 0 )
MODE=0 # 0=WORK; 1=BREAK
THIS_DIR=`dirname "$BASH_SOURCE"`

wait_seconds "${TIME_STRINGS[$MODE]}"
while ((1)); do
  iteration
done
