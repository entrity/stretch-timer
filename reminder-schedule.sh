REMINDER_INITIAL_DELAY_SECONDS=30
REMINDER_MAX_DELAY_SECONDS=$((32 * 60))
_REMINDER_SLEEP_PID=

_stop_reminder_sleep () {
  [[ -n $_REMINDER_SLEEP_PID ]] || return 0
  kill "$_REMINDER_SLEEP_PID" 2>/dev/null || true
  wait "$_REMINDER_SLEEP_PID" 2>/dev/null || true
  _REMINDER_SLEEP_PID=
}

_next_reminder_delay () {
  local delay=$1
  local next_delay=$((delay * 2))
  if ((next_delay > REMINDER_MAX_DELAY_SECONDS)); then
    next_delay=$REMINDER_MAX_DELAY_SECONDS
  fi
  printf '%s\n' "$next_delay"
}

_reminder_plays_sound () {
  local delay=$1
  ((delay < REMINDER_MAX_DELAY_SECONDS))
}

run_reminder_loop () {
  local title=$1
  local message=$2
  local delay=$REMINDER_INITIAL_DELAY_SECONDS
  local play_sound

  trap '_stop_reminder_sleep; exit 0' TERM INT

  while true; do
    sleep "$delay" &
    _REMINDER_SLEEP_PID=$!
    wait "$_REMINDER_SLEEP_PID"
    _REMINDER_SLEEP_PID=
    if ! is_idle; then
      play_sound=0
      _reminder_plays_sound "$delay" && play_sound=1
      remind "$title" "60" "$message" "$play_sound"
    fi
    delay=$(_next_reminder_delay "$delay")
  done
}
