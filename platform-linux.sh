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

prompt () {
  zenity --entry --title="$1" --text="$2" --entry-text="$3"
}

remind () {
  wmctrl -a "$1"
  ffplay -nodisp -autoexit -volume 20 /usr/share/sounds/sound-icons/prompt.wav 2>/dev/null
}

echo "Sourced Linux platform utils"
