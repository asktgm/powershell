#used in dRMM to map drive for Northcutt Elliott

$pw = "share"
$un = "share"
$drivePath = "\\192.168.4.12\Shares"
$driveLetter = "S"

(New-Object -ComObject "Wscript.Network").RemoveNetworkDrive("$($driveLetter):",$true,$true)
(New-Object -ComObject "Wscript.Network").MapNetworkDrive("$($driveLetter):", $drivePath.ToString(), $true, $un.ToString(),$pw.ToString())
(New-Object -ComObject shell.application).NameSpace( "$($driveLetter):\" ).self.name = "Shares"
