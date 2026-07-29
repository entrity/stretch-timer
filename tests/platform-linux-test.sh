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
  . "$THIS_DIR/../platform-linux.sh" >/dev/null
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
  . "$THIS_DIR/../platform-linux.sh" >/dev/null
}

test_prompt_does_not_leave_blocking_search_process () {
  local search_marker
  local child_marker
  local child_pid
  search_marker=$(mktemp)
  child_marker=$(mktemp)
  zenity () {
    local attempt
    for attempt in {1..100}; do
      [[ -s $search_marker ]] && return 0
      sleep 0.01
    done
    return 1
  }
  xrandr () {
    printf '%s\n' \
      "Monitors: 1" \
      " 0: +*eDP-1 1920/344x1200/215+0+0 eDP-1"
  }
  xdotool () {
    if [[ $1 == search ]]; then
      printf 'attempted\n' >"$search_marker"
      if [[ " $* " == *" --sync "* ]]; then
        sleep 30 &
        printf '%s\n' "$!" >"$child_marker"
        wait "$!"
      fi
      return 1
    fi
  }

  prompt "Pomodoro WORK" "Enter time" "20"
  child_pid=$(<"$child_marker")
  if [[ -n $child_pid ]] && kill -0 "$child_pid" 2>/dev/null; then
    printf 'FAIL: blocking search process survived after prompt returned\n' >&2
    FAILURES=$((FAILURES + 1))
    kill "$child_pid" 2>/dev/null || true
  fi

  rm "$search_marker" "$child_marker"
  unset -f zenity
  unset -f xrandr
  unset -f xdotool
}

test_missing_position_dependencies_are_nonfatal () {
  local status
  (
    unset -f xrandr xdotool
    PATH=/nonexistent
    _center_zenity_window "$$"
  )
  status=$?
  assert_eq "0" "$status" "ignores missing positioning dependencies"
}

test_malformed_monitor_geometry_skips_window_search () {
  local search_marker
  search_marker=$(mktemp)
  xrandr () {
    printf 'malformed monitor data\n'
  }
  xdotool () {
    printf 'called\n' >"$search_marker"
    return 1
  }

  _center_zenity_window "$$"
  assert_eq "" "$(<"$search_marker")" \
    "skips window search when monitor geometry is malformed"

  rm "$search_marker"
  unset -f xrandr
  unset -f xdotool
}

test_failed_window_move_is_nonfatal () {
  local move_marker
  local status
  move_marker=$(mktemp)
  xrandr () {
    printf '%s\n' \
      "Monitors: 1" \
      " 0: +*eDP-1 1920/344x1200/215+0+0 eDP-1"
  }
  xdotool () {
    case $1 in
      search)
        printf '42\n'
        ;;
      getwindowgeometry)
        printf 'WIDTH=640\nHEIGHT=240\n'
        ;;
      windowmove)
        printf 'called\n' >"$move_marker"
        return 1
        ;;
    esac
  }

  _center_zenity_window "$$"
  status=$?
  assert_eq "called" "$(<"$move_marker")" "attempts the window move"
  assert_eq "0" "$status" "ignores a failed window move"

  rm "$move_marker"
  unset -f xrandr
  unset -f xdotool
}

test_remind_with_sound () {
  local focus_marker
  local sound_marker
  focus_marker=$(mktemp)
  sound_marker=$(mktemp)
  wmctrl () {
    printf 'focused\n' >"$focus_marker"
  }
  ffplay () {
    printf 'played\n' >"$sound_marker"
  }

  remind "Pomodoro WORK" "60" "WORK TIME" 1
  assert_eq "focused" "$(<"$focus_marker")" \
    "foregrounds the prompt when sound is enabled"
  assert_eq "played" "$(<"$sound_marker")" \
    "plays the reminder sound when enabled"

  rm "$focus_marker" "$sound_marker"
  unset -f wmctrl
  unset -f ffplay
}

test_remind_without_sound () {
  local focus_marker
  local sound_marker
  focus_marker=$(mktemp)
  sound_marker=$(mktemp)
  wmctrl () {
    printf 'focused\n' >"$focus_marker"
  }
  ffplay () {
    printf 'played\n' >"$sound_marker"
  }

  remind "Pomodoro WORK" "60" "WORK TIME" 0
  assert_eq "focused" "$(<"$focus_marker")" \
    "foregrounds the prompt when sound is disabled"
  assert_eq "" "$(<"$sound_marker")" \
    "does not play the reminder sound when disabled"

  rm "$focus_marker" "$sound_marker"
  unset -f wmctrl
  unset -f ffplay
}

test_center_coordinates_at_origin
test_center_coordinates_with_monitor_offset
test_center_coordinates_round_down
test_primary_monitor_geometry
test_window_size
test_prompt_preserves_output_and_status
test_centering_failure_does_not_change_prompt
test_prompt_does_not_leave_blocking_search_process
test_missing_position_dependencies_are_nonfatal
test_malformed_monitor_geometry_skips_window_search
test_failed_window_move_is_nonfatal
test_remind_with_sound
test_remind_without_sound

if ((FAILURES)); then
  exit 1
fi
printf 'All platform-linux tests passed\n'
