#!/bin/bash

set -uo pipefail

LOOP_PID=

cd "$(dirname "$BASH_SOURCE")"

# Detect OS
if uname -a | grep -q -i 'Microsoft'; then
  . platform-windows.sh
elif uname | grep -q Darwin; then
  . platform-mac.sh
elif uname | grep -q Linux; then
  . platform-linux.sh
else
  >&2 echo "ERROR: unrecognized OS"
  exit 1
fi

trap cleanup SIGINT

function cleanup () {
  >&2 echo "in CLEANUP ($LOOP_PID)"
  [[ -n $LOOP_PID ]] && kill $LOOP_PID
  exit
}

# Convert MM:SS to seconds
function time2sec () {
  local minpart=$(<<<"$1" grep -oP "^(-)?[0-9]+" )
  local secpart=$(<<<"$1" sed 's/-[.:]/:-/' | grep -oP "[.:][-0-9]+$" | grep -oP "[-0-9]+$" )
  echo $(( ${minpart:-0} * 60 + ${secpart:-0} ))
}

function prompt_for_time () {
  local TITLE="Pomodoro $1"
  while true; do
    {
      sleep 30
      # Loop without issuing reminder if the user is AFK
      is_idle || remind "$TITLE" "60" "$1 TIME"
    } >/dev/null
  done &
  LOOP_PID=$!
  prompt "$TITLE" "Enter the $1 time (M:S or M)" "$2"
  local ret=$?
  kill $LOOP_PID # After input returns
  LOOP_PID=
  return $ret
}

function wait_for_mode () {
  # Calculate seconds (and mode) for current interval
  local secs=$(time2sec ${TIME_STRINGS[$MODE]})
  if [[ ${secs:-0} -lt 0 ]]; then
    MODE=$(( 1 - MODE ))
    secs=$(( secs * -1 ))
  fi
  echo waiting seconds $secs
  DOCLICK=${DOCLICK} \
  DOBLINK=${DOBLINK} \
  "$THIS_DIR/click-seconds.sh" "${secs}"
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
  # Wait & click/blink
  wait_for_mode
}

# Define defaults, which can be overriden by config file or args
DOBLINK=0
DOCLICK=0
if [[ -f $HOME/.config/stretch-timer.conf ]]; then
  . $HOME/.config/stretch-timer.conf
fi
DEFAULT_WORK_MIN=${1:-20}
DEFAULT_BREAK_MIN=${2:-20} # old value was .30

# Organize data structures
DEFAULT_TIME_STRINGS=( ${DEFAULT_WORK_MIN} ${DEFAULT_BREAK_MIN} )
TIME_STRINGS=( ${DEFAULT_WORK_MIN} ${DEFAULT_BREAK_MIN} )
LABELS=( WORK BREAK )
SILENCE_DEFAULTS=( 1 0 )
MODE=0 # 0=WORK; 1=BREAK
THIS_DIR=`dirname "$BASH_SOURCE"`

wait_for_mode
while ((1)); do
  iteration
done
cleanup
