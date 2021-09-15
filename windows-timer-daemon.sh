#!/bin/bash

WORK_MIN=${1:-20}
BREAK_MIN=${2:-3}
THIS_DIR=`dirname "$0"`

function await_seconds_silently () {
  SILENT=1 "$THIS_DIR/click-seconds.sh" $1
}

function await_seconds_with_clicks () {
  "$THIS_DIR/click-seconds.sh" $1
}

# Open up Windows GUI prompt
# @args: title, msg, default-value
function windows_prompt () {
  powershell.exe -File prompt.ps1 "${@}" | tr -d $'\r'
}

function iteration () {
  # Start work
  await_seconds_silently $(( WORK_MIN * 60 ))
  # Start break
  tput bel
  sleep 0.2
  tput bel
  BREAK_MIN=`windows_prompt 'Pomodoro BREAK' 'Enter the BREAK minutes' $BREAK_MIN`
  if [[ -z $BREAK_MIN ]]; then exit 1; fi
  await_seconds_with_clicks $(( BREAK_MIN * 60 ))
  # Prompt for next work
  WORK_MIN=`windows_prompt 'Pomodoro WORK' 'Enter the WORK minutes' $WORK_MIN`
}

while ((1)); do
  iteration
done
