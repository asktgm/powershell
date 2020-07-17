#used in dRMM to map drives for VRPL HQ

$pw = "share"
$un = "share"
$drivePathSCANS = "\\VRPWKS010\public\TOSHIBA"
$drivePathPUBLIC = "\\VRPWKS010\public"
$drivePathACCOUNTING = "\\VRPWKS010\Accounting"
$driveLetterSCANS = "X"
$driveLetterPUBLIC = "Y"
$driveLetterACCOUNTING = "Z"

(New-Object -ComObject "Wscript.Network").RemoveNetworkDrive("$($driveLetterSCANS):",$true,$true)
(New-Object -ComObject "Wscript.Network").RemoveNetworkDrive("$($driveLetterPUBLIC):",$true,$true)
(New-Object -ComObject "Wscript.Network").RemoveNetworkDrive("$($driveLetterACCOUNTING):",$true,$true)

(New-Object -ComObject "Wscript.Network").MapNetworkDrive("$($driveLetterSCANS):", $drivePathSCANS.ToString(), $true, $un.ToString(),$pw.ToString())
(New-Object -ComObject "Wscript.Network").MapNetworkDrive("$($driveLetterPUBLIC):", $drivePathPUBLIC.ToString(), $true, $un.ToString(),$pw.ToString())
(New-Object -ComObject "Wscript.Network").MapNetworkDrive("$($driveLetterACCOUNTING):", $drivePathACCOUNTING.ToString(), $true, $un.ToString(),$pw.ToString())

(New-Object -ComObject shell.application).NameSpace( "$($driveLetterSCANS):\" ).self.name = "Scans"
(New-Object -ComObject shell.application).NameSpace( "$($driveLetterPUBLIC):\" ).self.name = "Public"
(New-Object -ComObject shell.application).NameSpace( "$($driveLetterACCOUNTING):\" ).self.name = "Accounting"