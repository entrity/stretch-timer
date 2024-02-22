OS=windows

is_idle () {
	false # Not implemented yet
}

prompt () {
	powershell.exe -File "`wslpath -w prompt.ps1`" "$1" "$2" "$3" | tr -d $'\r' &
	__get_windows_pid | while read pid; do
		__window_to_foreground "$pid"
	done >/dev/null
}

remind () {
	>&2 echo remind...
	powershell.exe -File "`wslpath -w windows-notification.ps1`" -title "$1" -ttl "$2" "$3"
	__get_windows_pid | while read pid; do
		__window_to_foreground "$pid"
	done
}

__window_to_foreground () {
	target_pid=$1
	cat <<-EOF | powershell.exe
		Get-Process -id ${target_pid}
    \$sig = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    Add-Type -MemberDefinition \$sig -name NativeMethods -namespace Win32
    \$hwnd = @(Get-Process -id ${target_pid})[0].MainWindowHandle
    # Minimize window
    #[Win32.NativeMethods]::ShowWindowAsync(\$hwnd, 2)
    # Restore window
    [Win32.NativeMethods]::ShowWindowAsync(\$hwnd, 4)
	EOF
}

__get_windows_pid () {
	powershell.exe wmic path win32_process get processid,commandline \
	| grep -P 'prompt\.ps1|windows-notification\.ps1' \
	| grep -oP '\d+\s*$' \
	| sed 's/[[:space:]]\+//'
}
