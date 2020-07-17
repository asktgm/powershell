# novabench CLI
# intended to be used in dRMM as a component
# written by Andrew Newell
# Last modified October 4, 2019

#flag to write UDF or not, in case it's just a one-off?
#dRMM seems to pass all user variables as a strings so this is why I explicitly set the bool value here
if ($env:writeToUDF -eq 'false'){$writeToUDF = $false}else{$writeToUDF = $true}


$regPath = "HKLM:\SOFTWARE\CentraStage"
$regName = New-Object psobject
$regName | Add-Member NoteProperty cpu "Custom25" #CPU
$regName | Add-Member NoteProperty ram "Custom26" #RAM
$regName | Add-Member NoteProperty gpu "Custom27" #GPU
$regName | Add-Member NoteProperty disk "Custom28" #Disk
$regName | Add-Member NoteProperty diskdetail "Custom29" #Disk detail
$regName | Add-Member NoteProperty ramdetail "Custom30" #RAM detail

$BR = New-Object psobject #benchmark results
$BR | Add-Member NoteProperty cpu "_default"
$BR | Add-Member NoteProperty ram "_default"
$BR | Add-Member NoteProperty gpu "_default"
$BR | Add-Member NoteProperty disk "_default"
$BR | Add-Member NoteProperty diskdetail "_default"
$BR | Add-Member NoteProperty ramdetail "_default"

#function for unzipping
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

#set up dirs and extract the program
$workingDirPath = "$($env:HOMEDRIVE)\WITS"
if (-Not (Test-Path $workingDirPath)){New-Item -ItemType Directory $workingDirPath | Out-Null } #create directory if doesn't exist
$workingDir = Get-Item $workingDirPath -Force
$workingDir.Attributes="Hidden"
Copy-Item novabench.zip $workingDirPath
Unzip "$($workingDirPath)\novabench.zip" "$($workingDirPath)\"

#gather info about memory and disk
$ramDetails = Get-WmiObject -Class "win32_PhysicalMemory" -namespace "root\CIMV2" | Select-Object PartNumber,DeviceLocator
$diskDetails = Get-PhysicalDisk | Where-Object {$_.DeviceId -eq "0"} | Select-Object MediaType,FriendlyName #only gather index 0 (boot drive)

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

#write to UDF
# Write-Host "DEBUG: env:writeToUDF raw = $env:writeToUDF"
# Write-Host "DEBUG: writeToUDF = $writeToUDF"
# Write-Host "DEBUG: if statement evaluating to: $(if($writeToUDF){'true'}else{'false'})"
# Write-Host "DEBUG: if statement for env var evaluating to: $(if($env:writeToUDF){'true'}else{'false'})"
if ($writeToUDF){
    Write-Host "Benchmark ran - data writing to UDFs"
    #save the benchmark output in a file to parse easier
    $benchresult | Out-File "$($workingDirPath)\benchmark.txt"
    $d = "$($workingDirPath)\benchmark.txt"
    #gather each field for UDF
    $BR.cpu = Get-Content $d | Select-Object -Index 0
    $BR.ram = Get-Content $d | Select-Object -Index 3
    $BR.gpu = Get-Content $d | Select-Object -Index 6
    $BR.disk = Get-Content $d | Select-Object -Index 7
    $BR.diskdetail = "$($diskDetails.MediaType):$($diskDetails.FriendlyName)"
    #ram details are built dynamically in case there are multiple modules!
    if ($ramDetails.Length){
        for ($i = 0; $i -lt $ramDetails.Length; $i++) {
            if ($BR.ramdetail -eq "_default"){ #if first iteration
                $BR.ramdetail = "" #clear the value so we can build a string
            }else{
                $BR.ramdetail += "," #N+1 iteration, add a comma
            }
            $BR.ramdetail += "$($ramDetails.DeviceLocator[$i]):$($ramDetails.PartNumber[$i])" #build each piece in the array
        }
    }else{
        #if there's less than 2 dimm's we don't need a for loop
        $BR.ramdetail = "$($ramDetails.DeviceLocator):$($ramDetails.PartNumber)"
    }
    $BR.ramdetail = $BR.ramdetail -replace '\s','' #remove extra spacing finally

    #write data to UDFs
    if(!(Test-Path $regPath)){
        #reg key path doesn't exist, create it
        New-Item -Path $regPath -Force | Out-Null
    }
    New-ItemProperty -Path $regPath -Name $regName.cpu -Value $BR.cpu -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $regPath -Name $regName.ram -Value $BR.ram -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $regPath -Name $regName.gpu -Value $BR.gpu -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $regPath -Name $regName.disk -Value $BR.disk -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $regPath -Name $regName.diskdetail -Value $BR.diskdetail -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $regPath -Name $regName.ramdetail -Value $BR.ramdetail -PropertyType String -Force | Out-Null
}else{
    Write-Host "Benchmark Results:"
    Write-Host $benchresult
    Write-Host "Disk info:"
    Write-Host $diskDetails
    Write-Host "Memory info:"
    Write-Host $ramDetails
}


#now cleanup
Remove-Item $workingDirPath -Recurse -Force