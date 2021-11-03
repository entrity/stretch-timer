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

# I don't know why, but now I can't get a notification to appear unless I include this pointless line:
new-object system.windows.forms.notifyicon

$global:balmsg = New-Object System.Windows.Forms.NotifyIcon
$balmsg.Icon = [System.Drawing.SystemIcons]::Information
$balmsg.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::None
$balmsg.BalloonTipText = $msg
$balmsg.BalloonTipTitle = $title
$balmsg.Visible = $true
$balmsg.ShowBalloonTip($ttl)
