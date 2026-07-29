OS=linux

# GSM_PRESENCE_STATUS_IDLE defined in https://gitlab.gnome.org/GNOME/gnome-session/-/blob/e59b938c644a78236fd5ed9d708022be3b990ddc/gnome-session/gsm-presence.h
_GSM_PRESENCE_STATUS_IDLE=3

_get_gnome_session_manager_presence_status () {
  dbus-send --session --dest=org.gnome.SessionManager --print-reply=literal \
    /org/gnome/SessionManager/Presence org.freedesktop.DBus.Properties.Get \
    'string:org.gnome.SessionManager.Presence' 'string:status' \
    | grep --color=never -oP '\d+$'
}

is_idle () {
  local STATUS=$(_get_gnome_session_manager_presence_status)
  [[ $STATUS == $_GSM_PRESENCE_STATUS_IDLE ]]
}

_center_coordinates () {
  local monitor_x=$1
  local monitor_y=$2
  local monitor_width=$3
  local monitor_height=$4
  local window_width=$5
  local window_height=$6
  printf '%s %s\n' \
    "$((monitor_x + (monitor_width - window_width) / 2))" \
    "$((monitor_y + (monitor_height - window_height) / 2))"
}

_get_primary_monitor_geometry () {
  xrandr --listmonitors 2>/dev/null |
    awk '$2 ~ /\*/ { print $3; exit }' |
    sed -E \
      's#^([0-9]+)/[0-9]+x([0-9]+)/[0-9]+([+-][0-9]+)([+-][0-9]+)$#\3 \4 \1 \2#' |
    grep -E '^[+-][0-9]+ [+-][0-9]+ [0-9]+ [0-9]+$'
}

_get_window_size () {
  xdotool getwindowgeometry --shell "$1" 2>/dev/null |
    awk -F= '
      $1 == "WIDTH" { width = $2 }
      $1 == "HEIGHT" { height = $2 }
      END {
        if (width ~ /^[0-9]+$/ && height ~ /^[0-9]+$/) {
          print width, height
        } else {
          exit 1
        }
      }
    '
}

_center_zenity_window () {
  local zenity_pid=$1
  local monitor_geometry
  local window_id
  local window_size
  local coordinates

  command -v xrandr >/dev/null || return 0
  command -v xdotool >/dev/null || return 0
  monitor_geometry=$(_get_primary_monitor_geometry) || return 0
  window_id=$(xdotool search --sync --onlyvisible --pid "$zenity_pid" \
    2>/dev/null | head -n 1) || return 0
  [[ $window_id =~ ^[0-9]+$ ]] || return 0
  window_size=$(_get_window_size "$window_id") || return 0
  coordinates=$(_center_coordinates $monitor_geometry $window_size) ||
    return 0
  xdotool windowmove "$window_id" $coordinates >/dev/null 2>&1 || true
}

prompt () {
  zenity --entry --title="$1" --text="$2" --entry-text="$3" &
  local zenity_pid=$!
  _center_zenity_window "$zenity_pid" &
  local centering_pid=$!
  local zenity_status

  wait "$zenity_pid"
  zenity_status=$?
  kill "$centering_pid" 2>/dev/null || true
  wait "$centering_pid" 2>/dev/null || true
  return "$zenity_status"
}

remind () {
  wmctrl -a "$1"
  ffplay -nodisp -autoexit -volume 20 /usr/share/sounds/sound-icons/prompt.wav 2>/dev/null
}

echo "Sourced Linux platform utils"
