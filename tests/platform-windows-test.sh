#!/bin/bash

set -uo pipefail

THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$THIS_DIR/../platform-windows.sh" >/dev/null

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

test_audible_reminder_creates_notification () {
  local notification_marker
  notification_marker=$(mktemp)
  powershell.exe () {
    printf 'notified\n' >"$notification_marker"
  }
  wslpath () {
    printf 'windows-notification.ps1\n'
  }
  __get_windows_pid () {
    return 0
  }

  remind "Pomodoro WORK" "60" "WORK TIME" 1 2>/dev/null
  assert_eq "notified" "$(<"$notification_marker")" \
    "creates a Windows notification when sound is enabled"

  rm "$notification_marker"
  unset -f powershell.exe
  unset -f wslpath
  unset -f __get_windows_pid
}

test_silent_reminder_skips_notification () {
  local foreground_marker
  local notification_marker
  foreground_marker=$(mktemp)
  notification_marker=$(mktemp)
  powershell.exe () {
    printf 'notified\n' >"$notification_marker"
  }
  wslpath () {
    printf 'windows-notification.ps1\n'
  }
  __get_windows_pid () {
    printf '42\n'
  }
  __window_to_foreground () {
    printf 'focused\n' >"$foreground_marker"
  }

  remind "Pomodoro WORK" "60" "WORK TIME" 0 2>/dev/null
  assert_eq "" "$(<"$notification_marker")" \
    "skips the Windows notification when sound is disabled"
  assert_eq "focused" "$(<"$foreground_marker")" \
    "foregrounds the existing Windows prompt when sound is disabled"

  rm "$foreground_marker" "$notification_marker"
  unset -f powershell.exe
  unset -f wslpath
  unset -f __get_windows_pid
  unset -f __window_to_foreground
}

test_audible_reminder_creates_notification
test_silent_reminder_skips_notification

if ((FAILURES)); then
  exit 1
fi
printf 'All platform-windows tests passed\n'
