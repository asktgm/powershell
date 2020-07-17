#check the last log on / off via event log
#MONTHLY REPORT VERSION!
#ID 4672 = admin user log in
#ID 4624 = regular user log in
#ID 4647 = account log off
$userName = $env:accountname
#$numOfEvents = $env:PastNumberOfEvents
$timeLimit = [int]$env:pastMonths #customize how many past months to include
if ($null -eq $timeLimit){$timeLimit = 1} #default value
if ($timeLimit -gt 0){$timeLimit = $timeLimit * -1}
#$udfField = [string]$env:userCustomField.ToLower()

#if ($udfField -eq "default"){$udfField = "3"} #defaults to 3

#$regPath = "HKLM:\SOFTWARE\CentraStage"
#$regName = "Custom$($udfField)"
$lastLogONTime = @()
$lastLogOFFTime = @()
$errorfound = $false

#check log on events
$lastLogON = Get-EventLog -LogName Security -After (Get-Date).AddMonths($timeLimit) -InstanceId 4672 | Where-Object {$_.Message -like "*Account Name:*$($userName)*Account Domain:*$($env:COMPUTERNAME)*"}
if ($null -eq $lastLogON){
    #if null then try second method 4624
    $lastLogON = Get-EventLog -LogName Security -After (Get-Date).AddMonths($timeLimit) -InstanceId 4624 | Where-Object {$_.Message -like "*Account Name:*$($userName)*Account Domain:*$($env:COMPUTERNAME)*"}
    if ($null -ne $lastLogON){
        for ($counter=0; $counter -lt $lastLogON.Length; $counter++){
            $lastLogONTime += $lastLogON[$counter].TimeGenerated
        }
    }else{
        #all options failed
        $errorfound = $true
    }
}elseif ($null -ne $lastLogON) {
    #found using first method 4672
    for ($counter=0; $counter -lt $lastLogON.Length; $counter++){
        $lastLogONTime += $lastLogON[$counter].TimeGenerated
    }
}else{
    #this should never trigger, but just in case
    $errorfound = $true
}
$lastLogOFF = Get-EventLog -LogName Security -After (Get-Date).AddMonths($timeLimit) -InstanceId 4647 | Where-Object {$_.Message -like "*Account Name:*$($userName)*Account Domain:*$($env:COMPUTERNAME)*"}
if ($null -ne $lastLogOFF){
    for ($counter=0; $counter -lt $lastLogOFF.Length; $counter++){
        $lastLogOFFTime += $lastLogOFF[$counter].TimeGenerated
    }
}else{
    $errorfound = $true
}

#set value and write to registry for UDF
if (!$errorfound){

    Write-Host "Log in/out audit for previous $($timeLimit * -1) months"
    Write-Host "Checking for user account $userName"
    Write-Host "Log in events (found $($lastLogONTime.Length)): "
    foreach ($item in $lastLogONTime){
        Write-Host "`t$item"
    }
    Write-Host "Log out events (found $($lastLogOFFTime.Length)): "
    foreach ($item in $lastLogOFFTime){
        Write-Host "`t$item"
    }
}else{
    Write-Host "There was an issue locating the requested data. `n`nLookup unsuccessful!"
    exit 1;
}
