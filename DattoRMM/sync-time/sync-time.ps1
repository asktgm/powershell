# DattoRMM Component to automatically synchronize time on Windows
# Created by Andrew Newell
# Last Update: July 20, 2020

#set registry keys to force proper settings first
$regPath = @()
$regPath += "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters"
$regPath += "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate"
$regPath += "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation"
foreach ($item in $regPath){
    #create registry key paths if non-existent
    if (!(Test-Path -Path $item)){
        New-Item -Path $item
    }
}
Write-Host "Forcing NTP enabled. . ."
New-ItemProperty -Path $regPath[0] -Name "Type" -Value "NTP" -PropertyType String -Force | Out-Null
New-ItemProperty -Path $regPath[0] -Name "NtpServer" -Value "pool.ntp.org" -PropertyType String -Force | Out-Null
Write-Host "Forcing Time-Zone auto-update. . ."
New-ItemProperty -Path $regPath[1] -Name "Start" -Value 3 -PropertyType DWORD -Force | Out-Null
Write-Host "Forcing auto DST. . ."
New-ItemProperty -Path $regPath[2] -Name "DynamicDaylightTimeDisabled" -Value 0 -PropertyType DWORD -Force | Out-Null

#now try to force sync time
$out = w32tm.exe /resync /force
if ($LASTEXITCODE -ne 0){
    if ($out -like "*The service has not been started*"){
        Write-Host "Error found, service isn't started! Trying to start it. . ."
        try{
            if ((Get-Service -Name "W32Time").StartType -eq "Disabled"){
                Write-Host "W32Time service is disabled, enabling it. . ."
                Set-Service -Name "W32Time" -StartupType Automatic
            }
            Start-Service -Name "W32Time"
            if ((Get-Service -Name W32Time -ErrorAction SilentlyContinue).Status -eq "Running"){
                Write-Host "Service started successfully. . ."
                Write-Host "Trying to resynchronize again. . ."
                $again = w32tm.exe /config /manualpeerlist:"pool.ntp.org" /syncfromflags:manual /reliable:yes /update | Out-Null
                if ($LASTEXITCODE -eq 0){
                    Write-Host "Successfully resynchronized time!"
                }else{
                    Write-Host "Time resynchronization was unsuccessful."
                    exit 1
                }
            }else{
                Write-Host "The W32Time service couldn't be started for some reason."
            }
        }catch{
            Write-Host "Unable to start the service. Details:`n$_"
        }
    }
}