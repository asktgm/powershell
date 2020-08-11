#This script is used to remove any old Java versions, and leave only the newest.
#Original author: mmcpherson
#Modified/updated for Datto RMM by: Andrew Newell
#
#Version 1.0   - created 2015-04-24
#Version 1.1   - updated 2015-05-20
#              - Now also detects and removes old Java non-update base versions (i.e. Java versions without Update #)
#              - Now also removes Java 6 and below, plus added ability to manually change this behaviour.
#              - Added uninstall default behaviour to never reboot (now uses msiexec.exe for uninstall)
#Version 1.2   - updated 2015-07-28
#              - Bug fixes: null array and op_addition errors.
#
#Version 1.2.1 - updated 2020-07-21
#              - included option to filter static installs
# IMPORTANT NOTE: If you would like Java versions 6 and below to remain, please edit the next line and replace $true with $false
$UninstallJava6andBelow = $env:IncludeJava6AndLower
#convert data type from rmm
if ($UninstallJava6andBelow.ToLower() -eq "true"){$UninstallJava6andBelow = $true}else{$UninstallJava6andBelow = $false}
$keepStatic = $env:KeepStatic
#convert data type from rmm
if ($keepStatic.ToLower() -eq "true"){$keepStatic = $true}else{$keepStatic = $false}

#prevent running this on sensitive systems to limit potential issues
$osName = ((Get-WmiObject win32_OperatingSystem).Caption).ToLower()
if ((Get-Command -Name "Get-ExchangeServer" -ErrorAction SilentlyContinue) -or (Get-Service -name MSExchangeServiceHost -ErrorAction SilentlyContinue)){
    #exchange server
    Write-Host "ERROR: This script isn't supported running on an Exchange Server! Exiting. . ."
    exit 1;
}elseif (($osName -like "*small business*") -or ($osName -like "*sbs*")) {
    #sbs
    Write-Host "ERROR: This script isn't supported running on SBS OS versions! Exiting. . ."
    exit 1;
}

#Declare version arrays
$32bitJava = @()
$64bitJava = @()
$32bitVersions = @()
$64bitVersions = @()
 
#Perform WMI query to find installed Java Updates
if ($UninstallJava6andBelow) {
    $32bitJava += Get-WmiObject -Class Win32_Product | Where-Object { 
        $_.Name -match "(?i)Java(\(TM\))*\s\d+(\sUpdate\s\d+)*$"
    }
    #Also find Java version 5, but handled slightly different as CPU bit is only distinguishable by the GUID
    $32bitJava += Get-WmiObject -Class Win32_Product | Where-Object { 
        ($_.Name -match "(?i)J2SE\sRuntime\sEnvironment\s\d[.]\d(\sUpdate\s\d+)*$") -and ($_.IdentifyingNumber -match "^\{32")
    }
} else {
    $32bitJava += Get-WmiObject -Class Win32_Product | Where-Object { 
        $_.Name -match "(?i)Java((\(TM\) 7)|(\s\d+))(\sUpdate\s\d+)*$"
    }
}
 
#Perform WMI query to find installed Java Updates (64-bit)
if ($UninstallJava6andBelow) {
    #don't populate static installs in the list!
    $64bitJava += Get-WmiObject -Class Win32_Product | Where-Object { 
        ($_.Name -match "(?i)Java(\(TM\))*\s\d+(\sUpdate\s\d+)*\s[(]64-bit[)]$")
    }
    #Also find Java version 5, but handled slightly different as CPU bit is only distinguishable by the GUID
    $64bitJava += Get-WmiObject -Class Win32_Product | Where-Object { 
        ($_.Name -match "(?i)J2SE\sRuntime\sEnvironment\s\d[.]\d(\sUpdate\s\d+)*$") -and ($_.IdentifyingNumber -match "^\{64")
    }
} else {
    $64bitJava += Get-WmiObject -Class Win32_Product | Where-Object { 
        $_.Name -match "(?i)Java((\(TM\) 7)|(\s\d+))(\sUpdate\s\d+)*\s[(]64-bit[)]$"
    }
}

if ($keepStatic){
    #rebuild arrays by excluding static installs
    #static installs assumed to be installed in a non-standard directory
    #e.g. C:\Program Files\Trendex\Java\jre1.8.0_131\
    $newTempArray = @()
    foreach ($item in $64bitJava){
        if ($item.Properties | Where-Object {$_.Name -eq "InstallLocation" -and ($_.Value -like "*\Program Files (x86)\Java\*" -or $_.Value -like "*\Program Files\Java\*")}){
            $newTempArray += $item
        }
    }
    #reassign array and clear temp array for next loop
    $64bitJava = $newTempArray
    $newTempArray = @()
    foreach ($item in $32bitJava){
        if ($item.Properties | Where-Object {$_.Name -eq "InstallLocation" -and ($_.Value -like "*\Program Files (x86)\Java\*" -or $_.Value -like "*\Program Files\Java\*")}){
            $newTempArray += $item
        }
    }
    #reassign array
    $32bitJava = $newTempArray
    $newTempArray = $null
}
 
#Enumerate and populate array of versions
Foreach ($app in $32bitJava) {
    if ($null -ne $app) { $32bitVersions += $app.Version }
}
 
#Enumerate and populate array of versions
Foreach ($app in $64bitJava) {
    if ($null -ne $app) { $64bitVersions += $app.Version }
}
 
#Create an array that is sorted correctly by the actual Version (as a System.Version object) rather than by value.
$sorted32bitVersions = $32bitVersions | ForEach-Object{ New-Object System.Version ($_) } | Sort-Object
$sorted64bitVersions = $64bitVersions | ForEach-Object{ New-Object System.Version ($_) } | Sort-Object
#If a single result is returned, convert the result into a single value array so we don't run in to trouble calling .GetUpperBound later
if($sorted32bitVersions -isnot [system.array]) { $sorted32bitVersions = @($sorted32bitVersions)}
if($sorted64bitVersions -isnot [system.array]) { $sorted64bitVersions = @($sorted64bitVersions)}
#Grab the value of the newest version from the array, first converting 
$newest32bitVersion = $sorted32bitVersions[$sorted32bitVersions.GetUpperBound(0)]
$newest64bitVersion = $sorted64bitVersions[$sorted64bitVersions.GetUpperBound(0)]
 
Foreach ($app in $32bitJava) {
    if ($null -ne $app)
    {
        # Remove all versions of Java, where the version does not match the newest version.
        if (($app.Version -ne $newest32bitVersion) -and ($null -ne $newest32bitVersion)) {
           $appGUID = $app.Properties["IdentifyingNumber"].Value.ToString()
           Start-Process -FilePath "msiexec.exe" -ArgumentList "/qn /norestart /x $($appGUID)" -Wait -Passthru
           Write-Host "Uninstalling 32-bit version: " $app
        }
    }
}
 
Foreach ($app in $64bitJava) {
    if ($null -ne $app)
    {
        # Remove all versions of Java, where the version does not match the newest version.
        if (($app.Version -ne $newest64bitVersion) -and ($newest64bitVersion -ne $null)) {
        $appGUID = $app.Properties["IdentifyingNumber"].Value.ToString()
           Start-Process -FilePath "msiexec.exe" -ArgumentList "/qn /norestart /x $($appGUID)" -Wait -Passthru
           Write-Host "Uninstalling 64-bit version: " $app
        }
    }
}

Write-Host "Script Complete"