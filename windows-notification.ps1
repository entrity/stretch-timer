<#
One option for producing a notification in Windows

Usage:
  powershell.exe -File $0 [-title TITLE] [-ttl TTL] msg
#>

param (
  [string] $title,
  [int] $ttl = 2,
  [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
  [string] $msg
)

[reflection.assembly]::loadwithpartialname("System.Windows.Forms")
[reflection.assembly]::loadwithpartialname("System.Drawing")
$notify = new-object system.windows.forms.notifyicon
$notify.icon = [System.Drawing.SystemIcons]::Information
$notify.visible = $true
$notify.showballoontip($ttl,"$title",$msg,[system.windows.forms.tooltipicon]::None)
