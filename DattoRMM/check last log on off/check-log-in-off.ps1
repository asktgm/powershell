#check the last log on / off via event log
#ID 4672 = admin user log in
#ID 4624 = regular user log in
#ID 4647 = account log off
$userName = $env:accountname
$numOfEvents = $env:PastNumberOfEvents
$udfField = [string]$env:userCustomField.ToLower()

if ($udfField -eq "default"){$udfField = "3"} #defaults to 3

$regPath = "HKLM:\SOFTWARE\CentraStage"
$regName = "Custom$($udfField)"
$dayLimit = -10     #scan this far back only
$lastLogONTime = @()
$lastLogOFFTime = @()

#check log on events
$lastLogON = Get-EventLog -LogName Security -After (Get-Date).AddDays($dayLimit) -InstanceId 4672 | Where-Object {$_.Message -like "*Account Name:*$($userName)*Account Domain:*$($env:COMPUTERNAME)*"}
if ($null -eq $lastLogON){
    #if null then try second method 4624
    $lastLogON = Get-EventLog -LogName Security -After (Get-Date).AddDays($dayLimit) -InstanceId 4624 | Where-Object {$_.Message -like "*Account Name:*$($userName)*Account Domain:*$($env:COMPUTERNAME)*"}
    if ($null -ne $lastLogON){
        for ($counter=0; $counter -lt $numOfEvents; $counter++){
            $lastLogONTime += $lastLogON[$counter].TimeGenerated
        }
        #$lastLogON = $lastLogON[0].TimeGenerated
    }else{
        #all options failed
        $errorfound = $true
    }
}elseif ($null -ne $lastLogON) {
    #found using first method 4672
    for ($counter=0; $counter -lt $numOfEvents; $counter++){
        $lastLogONTime += $lastLogON[$counter].TimeGenerated
    }
    #$lastLogON = $lastLogON[0].TimeGenerated
}else{
    #this should never trigger, but just in case
    $errorfound = $true
}
$lastLogOFF = Get-EventLog -LogName Security -After (Get-Date).AddDays($dayLimit) -InstanceId 4647 | Where-Object {$_.Message -like "*Account Name:*$($userName)*Account Domain:*$($env:COMPUTERNAME)*"}
if ($null -ne $lastLogOFF){
    for ($counter=0; $counter -lt $numOfEvents; $counter++){
        $lastLogOFFTime += $lastLogOFF[$counter].TimeGenerated
    }
    #$lastLogOFF = $lastLogOFF[0].TimeGenerated
}else{
    $errorfound = $true
}

#set value and write to registry for UDF
if (!$errorfound){
    $regValue = "User: $userName"
    foreach ($item in $lastLogONTime){
        $regValue += " - log on: $item"
    }
    foreach ($item in $lastLogOFFTime){
        $regValue += " - log off: $item"
    }
    if(!(Test-Path $regPath)){
        New-Item -Path $regPath -Force | Out-Null
        New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType String -Force | Out-Null
    }else{
        New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType String -Force | Out-Null
    }
    Write-Host "Lookup successful, data written to UDF$udfField on device"
}else{
    Write-Host "There was an issue locating the requested data. `n`nLookup unsuccessful!"
}
