#!/bin/bash

set -uo pipefail

THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCHEDULE_FILE="$THIS_DIR/../reminder-schedule.sh"
[[ -f $SCHEDULE_FILE ]] && . "$SCHEDULE_FILE"

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

test_delay_sequence () {
  local delay=30
  local actual=$delay
  local iteration
  for iteration in {1..7}; do
    delay=$(_next_reminder_delay "$delay")
    actual+=" $delay"
  done
  assert_eq "30 60 120 240 480 960 1920 1920" "$actual" \
    "doubles reminder delays and caps them at 32 minutes"
}

test_sound_cutoff () {
  local actual=
  local delay
  for delay in 30 60 120 240 480 960 1920 3840; do
    if _reminder_plays_sound "$delay"; then
      actual+="1"
    else
      actual+="0"
    fi
  done
  assert_eq "11111100" "$actual" \
    "disables sound at and beyond the 32-minute delay"
}

test_loop_schedule_and_sound_flags () {
  local actual
  actual=$(
    sleep () {
      printf 'sleep=%s ' "$1"
    }
    is_idle () {
      return 1
    }
    remind () {
      printf 'sound=%s\n' "$4"
      reminder_count=$((reminder_count + 1))
      ((reminder_count == 8)) && exit 0
    }
    reminder_count=0
    run_reminder_loop "Pomodoro WORK" "WORK TIME"
  )
  assert_eq \
    $'sleep=30 sound=1\nsleep=60 sound=1\nsleep=120 sound=1\nsleep=240 sound=1\nsleep=480 sound=1\nsleep=960 sound=1\nsleep=1920 sound=0\nsleep=1920 sound=0' \
    "$actual" \
    "uses the capped schedule and silences 32-minute reminders"
}

test_loop_advances_schedule_while_idle () {
  local actual
  actual=$(
    sleep () {
      printf 'sleep=%s ' "$1"
    }
    is_idle () {
      idle_checks=$((idle_checks + 1))
      ((idle_checks < 3))
    }
    remind () {
      printf 'sound=%s\n' "$4"
      exit 0
    }
    idle_checks=0
    run_reminder_loop "Pomodoro WORK" "WORK TIME"
  )
  assert_eq \
    "sleep=30 sleep=60 sleep=120 sound=1" \
    "$actual" \
    "advances the reminder schedule while idle"
}

test_loop_cleans_up_active_sleep () {
  local sleep_pid_file
  local loop_pid
  local sleep_pid
  local attempt
  sleep_pid_file=$(mktemp)

  PATH="$THIS_DIR/fixtures/bin:$PATH" \
    SLEEP_PID_FILE="$sleep_pid_file" \
    run_reminder_loop "Pomodoro WORK" "WORK TIME" &
  loop_pid=$!

  for attempt in {1..100}; do
    [[ -s $sleep_pid_file ]] && break
    /bin/sleep 0.01
  done
  sleep_pid=$(<"$sleep_pid_file")
  kill "$loop_pid"
  wait "$loop_pid" 2>/dev/null || true

  if [[ -z $sleep_pid ]]; then
    printf 'FAIL: reminder sleep did not start during cleanup test\n' >&2
    FAILURES=$((FAILURES + 1))
  elif kill -0 "$sleep_pid" 2>/dev/null; then
    printf 'FAIL: reminder sleep survived after loop termination\n' >&2
    FAILURES=$((FAILURES + 1))
    kill "$sleep_pid" 2>/dev/null || true
  fi

  rm "$sleep_pid_file"
}

test_delay_sequence
test_sound_cutoff
test_loop_schedule_and_sound_flags
test_loop_advances_schedule_while_idle
test_loop_cleans_up_active_sleep

if ((FAILURES)); then
  exit 1
fi
printf 'All reminder schedule tests passed\n'
