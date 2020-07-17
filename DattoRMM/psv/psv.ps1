#dRMM component used gather powershell version and save in device UDF

#UDF
$regPath = "HKLM:\SOFTWARE\CentraStage"
$regName = New-Object psobject
$regName | Add-Member NoteProperty psv "Custom7" #version data

$psv = ($PSVersionTable).PSVersion.ToString()
Write-Host "PowerShell version: $psv"
Write-Host "Writing to UDF. . ."
try{
    if(!(Test-Path $regPath)){
        #reg key path doesn't exist, create it
        New-Item -Path $regPath -Force | Out-Null
    }
    New-ItemProperty -Path $regPath -Name $regName.psv -Value $psv -PropertyType String -Force | Out-Null
    Write-Host "SUCCESS: UDF Updated!"
    exit 0;
}catch{
    Write-Host "ERROR: There was an issue writing the UDF"
    exit 1;
}