OS=windows

is_idle () {
  false # Not implemented yet
}

prompt () {
  powershell.exe -File "`wslpath -w prompt.ps1`" "$1" "$2" "$3" | tr -d $'\r'
}

remind () {
  powershell.exe -File "`wslpath -w windows-notification.ps1`" -title "$1" -ttl "$2" "$3"
}
