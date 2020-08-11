param (
    [string[]]$Targets = @("127.0.0.1"),
    [int]$Frequency = 5,
    [int]$Duration = 1
)
#begin data validations
if ([string]::IsNullOrEmpty($Targets)){
    #no target passed
    Write-Host -ForegroundColor Red "Error: No targets provided!"
    exit 1;
}
if (!($Frequency -ge 5)){
    #minimum 5 second frequency
    Write-Host -ForegroundColor Red "Error: Frequency must be greater than or equal to 5"
    exit 1;
}
#split the targets into an array
$Targets = $Targets.Split(" ")

if (!($Duration -ge 1)){
    #duration minimum 1 hour
    Write-Host -ForegroundColor Red "Error: Invalid duration specified, must be greater than 0"
    exit 1;
}else{
    $endTime = (Get-Date).AddHours($Duration)
}
#validate IP addresses
foreach($ip in $Targets){
    if (!($ip -match "\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.|$)){4}\b")){
        Write-Host -ForegroundColor Red "Error: Invalid IP address passed, only IPv4 addresses supported and multiple addresses should be separated by a space. Problem address: $ip"
        exit 1;
    }
}
#end data validations
Clear-Host

$outFile = "$PSScriptRoot\net-monitor_$(Get-Date -Format dMMyyyy).csv"
Write-Host -ForegroundColor Yellow "`n`n`n`n`n`n`n`n`n`n"
Write-Host -ForegroundColor Yellow "Info: Script starting at $(Get-Date)"
Write-Host -ForegroundColor Yellow "Info: Will run for $Duration hours until $endTime"
Write-Host -ForegroundColor Yellow "Info: Press Ctrl+C to end early"
while ((Get-Date) -lt $endTime){
    foreach($ip in $Targets){
        $x = Test-NetConnection -RemoteAddress $ip
        $csvData = New-Object PSObject
        $csvData | Add-Member -MemberType NoteProperty -Name "Time" -Value (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss')
        $csvData | Add-Member -MemberType NoteProperty -Name "Target" -Value $ip
        $csvData | Add-Member -MemberType NoteProperty -Name "Successful" -Value $x.PingSucceeded
        $csvData | Add-Member -MemberType NoteProperty -Name "Ping" -Value $x.PingReplyDetails.RoundtripTime
        Export-Csv -InputObject $csvData -Path $outFile -NoTypeInformation -Append
    }
    Start-Sleep -Seconds $Frequency
}
Write-Host "Info: Script completed running for $Duration hour(s)"