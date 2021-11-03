#!/bin/bash

# Convert MM:SS to seconds
function time2sec () {
  local minpart=$(<<<"$1" grep -oP "^(-)?[0-9]+" )
  local secpart=$(<<<"$1" sed 's/-[.:]/:-/' | grep -oP "[.:][-0-9]+$" | grep -oP "[-0-9]+$" )
  echo $(( ${minpart:-0} * 60 + ${secpart:-0} ))
}

function prompt_for_time () {
  while true; do
    >/dev/null powershell.exe -File windows-notification.ps1 -title "Pomoodoro" -ttl 60 "$1 TIME"
    >/dev/null sleep 30
  done &
  loop_id=$!
  powershell.exe -File prompt.ps1 "Pomoodoro $1" "Enter the $1 time (M:S or M)" $2 | tr -d $'\r'
  kill $loop_id # After input returns
}

function iteration () {
  # Wait/click
  SILENT=${SILENCE_DEFAULTS[$MODE]} "$THIS_DIR/click-seconds.sh" ${SECS[$MODE]}
  # Get time string for next interval
  MODE=$(( 1 - MODE ))
  TIME_STRINGS[$MODE]=$(prompt_for_time "${LABELS[$MODE]}" ${TIME_STRINGS[$MODE]})
  [[ -z ${TIME_STRINGS[$MODE]} ]] && exit 1
  local secs=$(time2sec "${TIME_STRINGS[$MODE]}")
  # Repeat current mode if time is negative
  if [[ $secs -lt 0 ]]; then
    MODE=$(( 1 - MODE ))
    secs=$(( secs * -1 ))
  fi
  # Set seconds for next interval
  SECS[$MODE]=$secs
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
