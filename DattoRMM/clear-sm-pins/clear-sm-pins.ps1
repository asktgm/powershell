#Clear start menu pins script
#straight copy/paste from new pc script, needs to be updated for drmm

$smPins1PATH = ".\sm-layout-clean.reg"
$smPins2PATH = ".\sm-layout-unlock.reg"
$smPins3PATH = ".\defaultlayout.xml"
$runningUser = whoami.exe

if ($runningUser -ne "nt authority\system"){
    Write-Host "- Applying SM changes -"
    #move the xml file into place
    #apply first registry edit
    Write-Host "Applying first registry edit. . ."
    reg.exe import $smPins1PATH
    #kill explorer to force update
    Write-Host "Killing explorer to apply changes. . ."
    taskkill.exe /f /im explorer.exe > $null 2>&1
    ping.exe -n 3 localhost > null 2>&1 #artificial delay ~3 seconds
    Write-Host "Restarting explorer. . ."
    Start-Process explorer.exe #restart explorer
    ping.exe -n 6 localhost > null 2>&1 #artificial delay ~6 seconds
    #apply second registry edit
    Write-Host "Applying second registry edit. . ."
    reg.exe import $smPins2PATH
    #kill explorer again
    Write-Host "Killing explorer to apply changes. . ."
    taskkill.exe /f /im explorer.exe > $null 2>&1
    ping.exe -n 3 localhost > null 2>&1 #artificial delay ~3 seconds
    Write-Host "Restarting explorer. . ."
    Start-Process explorer.exe
    ping.exe -n 6 localhost > null 2>&1 #artificial delay ~6 seconds
    #done
    Write-Host "- Script Complete -"
}else{
    Write-Host "Error: This script needs to be run as the user administrator!"
    exit 1
}