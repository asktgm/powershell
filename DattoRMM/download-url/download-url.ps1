# used to download a provided item from a web url

if ($env:isOneDrive -eq "1"){
    $isOneDrive = $true
}else{
    $isOneDrive = $false
}
$targURL = $env:TargetUrl
$dlPath = "$env:HOMEDRIVE\WITS"
$dlFile = $env:FileName
$fullPath = "$($dlPath)\$($dlFile)"

if(!(Test-Path $dlPath)){
    New-Item -ItemType Directory -Path $dlPath | Out-Null
    Write-Host "Created $dlPath"
}

if ($isOneDrive){
    #use different method for OneDrive/SharePoint URLs
    $odURL = "$($targURL)&download=1" #append download variable
    Start-BitsTransfer -Source $odURL -Destination $fullPath
}else{
    $client = New-Object System.Net.WebClient
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12; # set tls version explicitly
    $client.DownloadFile($targURL, "$dlPath\$dlFile")
}

if (Test-Path $fullPath){
    Write-Host "File downloaded to $fullPath"
    exit 0
}else{
    Write-Host "There was an error downloading the file."
    exit 1
}