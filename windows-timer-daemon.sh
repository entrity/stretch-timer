#!/bin/bash

WORK_TIME=${1:-20}
BREAK_TIME=${2:-3}
THIS_DIR=`dirname "$0"`

# Convert MM:SS to seconds
function time2sec () {
  local parts=( $(<<<"$1" tr ":" "\n")  )
  local minpart=${parts[0]:-0}
  local secpart=${parts[1]:-0}
  echo $(( minpart * 60 + secpart ))
}

function prompt_for_time () {
  while true; do
    >/dev/null powershell.exe -File windows-notification.ps1 -title "Pomoodoro" -ttl 60 "$1 TIME"
    >/dev/null sleep 6
  done &
  loop_id=$!
  powershell.exe -File prompt.ps1 "Pomoodoro $1" "Enter the $1 time (M:S or M)" $2 | tr -d $'\r'
  kill $loop_id # After input returns
}

function iteration () {
  # Start work
  SILENT=1 "$THIS_DIR/click-seconds.sh" $WORK_SEC
  # Start break
  tput bel
  BREAK_TIME=$(prompt_for_time 'BREAK' $BREAK_TIME)
  [[ -z $BREAK_TIME ]] && exit 1
  BREAK_SEC=$(time2sec $BREAK_TIME)
  "$THIS_DIR/click-seconds.sh" $BREAK_SEC
  # Prompt for next work
  WORK_TIME=$(prompt_for_time 'WORK' $WORK_TIME)
  [[ -z $WORK_TIME ]] && exit 1
  WORK_SEC=$(time2sec $WORK_TIME)
}

WORK_SEC=$(time2sec $WORK_TIME)
BREAK_SEC=$(time2sec $BREAK_TIME)
while ((1)); do
  iteration
done
