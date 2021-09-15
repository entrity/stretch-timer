<#
One option for producing a notification in Windows

Usage:
  powershell.exe -File $0 [-title TITLE] msg

Ref:
  http://woshub.com/popup-notification-powershell/
#>

param (
  [string] $title,
  [int] $ttl = 45,
  [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
  [string] $msg
)

function Do-Popup {
  $wshell = New-Object -ComObject Wscript.Shell
  $Output = $wshell.Popup("$msg", $ttl, "$title", 48)
  return $Output
}

$Output = -1
while ( $Output -eq -1 )
{
  $Output = Do-Popup
  Write-Output output is $Output
}
