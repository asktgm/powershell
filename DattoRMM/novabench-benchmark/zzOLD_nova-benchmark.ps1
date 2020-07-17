# novabench CLI
# intended to be used in dRMM as a component

$writeToUDF = [bool]$env:writeToUDF #flag to write UDF or not, in case it's just a one-off?
$udfField = [string]$env:udfFieldNumber.ToLower()

if ($udfField -eq "default"){$udfField = "6"} #defaults to 6 - benchmark data

$regPath = "HKLM:\SOFTWARE\CentraStage"
$regName = "Custom$($udfField)"

#function for unzipping
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

$workingDirPath = "$($env:HOMEDRIVE)\WITS"
if (-Not (Test-Path $workingDirPath)){New-Item -ItemType Directory $workingDirPath | Out-Null } #create directory if doesn't exist
$workingDir = Get-Item $workingDirPath -Force
$workingDir.Attributes="Hidden"
Copy-Item novabench.zip $workingDirPath
Unzip "$($workingDirPath)\novabench.zip" "$($workingDirPath)\"

#pulled from https://stackoverflow.com/questions/8761888/capturing-standard-out-and-error-with-start-process
$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = "$($workingDirPath)\novabench.exe"
$pinfo.RedirectStandardError = $true
$pinfo.RedirectStandardOutput = $true
$pinfo.UseShellExecute = $false
$pinfo.Arguments = "/t all /o human /p $($env:HOMEDRIVE)\"
$p = New-Object System.Diagnostics.Process
$p.StartInfo = $pinfo
$p.Start() | Out-Null
$p.WaitForExit()
$stdout = $p.StandardOutput.ReadToEnd()
$stderr = $p.StandardError.ReadToEnd()
$benchresult = $stdout
Write-Host $benchresult

#write to UDF
if ($writeToUDF){
    #build single line for UDF
    $benchresult | Out-File "$($workingDirPath)\benchmark.txt"
    $d = "$($workingDirPath)\benchmark.txt"
    $benchresult = Get-Content $d | Select-Object -Index 0 #CPU
    $benchresult += " | "
    $benchresult += Get-Content $d | Select-Object -Index 3 #RAM
    $benchresult += " | "
    $benchresult += Get-Content $d | Select-Object -Index 6 #GPU
    $benchresult += " | "
    $benchresult += Get-Content $d | Select-Object -Index 7 #Disk
    

    $regValue = $benchresult
    #write data to UDF
    if(!(Test-Path $regPath)){
        #reg key path doesn't exist, create it
        New-Item -Path $regPath -Force | Out-Null
        New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType String -Force | Out-Null
    }else{
        New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType String -Force | Out-Null
    }
}


#now cleanup
Remove-Item $workingDirPath -Recurse -Force