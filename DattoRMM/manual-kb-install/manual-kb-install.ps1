#PS script to manually download and attempt to install a KB
#written by Andrew Newell
#last update July 29th 2020
$dlURL = $env:DownloadURL
$timeOutThreshold = [int32]$env:TimeoutThreshold #how long to wait (mins) for WUSA to complete before giving up
if ([string]::IsNullOrEmpty($timeOutThreshold)){
    #default value for no entry
    $timeOutThreshold = 15
}
if ($timeOutThreshold -gt 60){ $timeOutThreshold = 60; Write-Host "Info: Enforcing timeout threshold to 60 minutes"}
$workingDir = "$env:SystemDrive\WITS-Temp"
$wusaFile = "$env:SystemRoot\System32\wusa.exe"
$argList = "/quiet /norestart /log:$workingDir"
$counter = 0
$client = New-Object System.Net.WebClient
# set tls version explicitly
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12 

if ($dlURL -match "^.{1,}(kb\d{7}).{1,}\.msu$"){
    #found the KB number in the URL
    $kbNum = $Matches[1]
    Write-Host "Info: Detected KB - $kbNum"
}else{
    Write-Host "Error: Unable to determine KB number from URL, exiting..."
    exit 1;
}
#update variables to include KB number
$dlFile = "$kbNum.msu"
$argList = "$workingDir\$dlFile $argList\$kbNum.evt"

#create working folder if doesn't exist
if (!(Test-Path -Path $workingDir)){
    New-Item -ItemType Directory -Path $workingDir -Force
}elseif((Get-ChildItem -Path $workingDir).Length -gt 0){
    #working folder exists and already has stuff in it
    Write-Host "Info: Found existing working folder with items inside - cleaning up:`n"
    Get-ChildItem -Path $workingDir | Remove-Item -Force -Verbose
}
(Get-Item -Path $workingDir).Attributes = "Hidden" #hide the folder
Write-Host "Info: Downloading file from URL..."
$client.DownloadFile($dlURL, "$workingDir\$dlFile") #download the file
if(Test-Path -Path "$workingDir\$dlFile"){
    Write-Host "Info: File download completed successfully"
}else{
    Write-Host "Error: File did not download successfully, exiting..."
    Write-Host "Debug: `$workingDir = $workingDir `nDebug: `$dlFile = $dlFile "
    exit 1;
}
#start wusa to install and log
Write-Host "Info: Attempting to use WUSA to install update file..."
Start-Process -FilePath $wusaFile -ArgumentList $argList
#wait for wusa to stop or 15 mins
while ((Get-Process -Name wusa -ErrorAction SilentlyContinue) -or ($counter -ge $timeOutThreshold)){
    Write-Host "Info: WUSA process running. Checking again in 60 seconds..."
    $counter += 1
    Start-Sleep -Seconds 60
}
if ($counter -ge $timeOutThreshold){
    Write-Host "Info: WUSA has been running for longer than $counter minutes. Attempting to read current log file:`n"  
}else{
    Write-Host "Info: WUSA has completed, reading log file into console:`n"
}
Get-WinEvent -Path "$workingDir\$kbNum.evt" -Oldest | Sort-Object -Property @{Expression="TimeCreated";Descending=$false} | Format-List
Write-Host "Info: End of log file"
if (!(Get-Process -Name wusa -ErrorAction SilentlyContinue)){
    #clean up working directory if WUSA not running
    Write-Host "Info: Cleaning up working directory"
    Get-ChildItem -Path $workingDir | Remove-Item -Force
    Get-Item -Path $workingDir | Remove-Item -Force
}
Write-Host "Script Complete"
