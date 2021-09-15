<#

Usage:
  powershell.exe -File $0 <TITLE> <MSG> <DEFAULT_VALUE>

Ref.
  https://social.technet.microsoft.com/Forums/lync/en-US/40f938b0-be95-4abc-8194-e4d8c4ccc857/powershell-script-popup?forum=winserverpowershell

#>

Param (
  [string] $title,
  [string] $msg,
  [string] $value
)

Add-Type -AssemblyName Microsoft.VisualBasic

$folderName = [Microsoft.VisualBasic.Interaction]::InputBox($title, $msg, $value)

$folderName
