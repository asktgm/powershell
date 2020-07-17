# this script is intended to be run in a dRMM component
# it will compress a target file into a WITS folder located on the root C:\ drive

$targFile = $env:TargetFileToCompress
$compressFile = "C:\WITS\compressed-file.7z"

#check for 7zip exe
if (Test-Path -Path "C:\Program Files\7-Zip\7z.exe"){
    $7zExe = "C:\Program Files\7-Zip\7z.exe"
}elseif (Test-Path -Path "C:\Program Files (x86)\7-Zip\7z.exe") {
    $7zExe = "C:\Program Files (x86)\7-Zip\7z.exe"
}else{
    #can't find 7zip install
    $7zExe = $false
}

if ($null -ne $7zExe){
    if (!(Test-Path -Path "C:\WITS")){
        New-Item -ItemType Directory -Name "WITS" -Path "C:\" | Out-Null
        Write-Host "Created C:\WITS folder"
    }
    Write-Host "Attempting to compress file: $compressFile"
    $7zArgs = "a `"$compressFile`" `"$targFile`""
    Start-Process $7zExe $7zArgs -Wait
    Write-Host "Process finished"
}else{
    Write-Host "There was an error running the component, 7-Zip installation could not be found!"
    exit 1;
}