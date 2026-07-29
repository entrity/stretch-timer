#!/bin/bash

set -uo pipefail

THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$THIS_DIR/../platform-linux.sh" >/dev/null

FAILURES=0

assert_eq () {
  local expected=$1
  local actual=$2
  local description=$3
  if [[ $actual != "$expected" ]]; then
    printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' \
      "$description" "$expected" "$actual" >&2
    FAILURES=$((FAILURES + 1))
  fi
}

test_center_coordinates_at_origin () {
  assert_eq "810 450" "$(_center_coordinates 0 0 1920 1080 300 180)" \
    "centers a window on a monitor at the origin"
}

test_center_coordinates_with_monitor_offset () {
  assert_eq "4010 660" "$(_center_coordinates 3440 240 1920 1200 780 360)" \
    "includes the primary monitor offset"
}

test_center_coordinates_round_down () {
  assert_eq "2 3" "$(_center_coordinates 0 0 6 8 1 1)" \
    "uses Bash integer division for odd differences"
}

test_primary_monitor_geometry () {
  xrandr () {
    printf '%s\n' \
      "Monitors: 2" \
      " 0: +HDMI-1-0 3440/800x1440/335+0+0 HDMI-1-0" \
      " 1: +*eDP-1 1920/344x1200/215+3440+240 eDP-1"
  }
  assert_eq "+3440 +240 1920 1200" "$(_get_primary_monitor_geometry)" \
    "parses the primary monitor and its nonzero origin"
  unset -f xrandr
}

test_window_size () {
  xdotool () {
    printf '%s\n' \
      "WINDOW=42" \
      "X=100" \
      "Y=200" \
      "WIDTH=640" \
      "HEIGHT=240" \
      "SCREEN=0"
  }
  assert_eq "640 240" "$(_get_window_size 42)" \
    "parses xdotool shell geometry"
  unset -f xdotool
}

test_prompt_preserves_output_and_status () {
  local center_marker
  center_marker=$(mktemp)
  zenity () {
    printf '20:00\n'
    return 7
  }
  _center_zenity_window () {
    printf 'called\n' >"$center_marker"
    return 0
  }

  local output
  local status
  output=$(prompt "Pomodoro WORK" "Enter time" "20")
  status=$?

  assert_eq "20:00" "$output" "preserves Zenity standard output"
  assert_eq "7" "$status" "preserves Zenity exit status"
  assert_eq "called" "$(<"$center_marker")" "runs the centering helper"
  rm "$center_marker"
  unset -f zenity
  unset -f _center_zenity_window
}

test_centering_failure_does_not_change_prompt () {
  local center_marker
  center_marker=$(mktemp)
  zenity () {
    printf '30\n'
    return 0
  }
  _center_zenity_window () {
    printf 'called\n' >"$center_marker"
    return 1
  }

  local output
  local status
  output=$(prompt "Pomodoro BREAK" "Enter time" "20")
  status=$?

  assert_eq "30" "$output" "keeps output when centering fails"
  assert_eq "0" "$status" "keeps status when centering fails"
  assert_eq "called" "$(<"$center_marker")" \
    "attempts centering without making it fatal"
  rm "$center_marker"
  unset -f zenity
  unset -f _center_zenity_window
}

test_center_coordinates_at_origin
test_center_coordinates_with_monitor_offset
test_center_coordinates_round_down
test_primary_monitor_geometry
test_window_size
test_prompt_preserves_output_and_status
test_centering_failure_does_not_change_prompt

if ((FAILURES)); then
  exit 1
fi
printf 'All platform-linux tests passed\n'
