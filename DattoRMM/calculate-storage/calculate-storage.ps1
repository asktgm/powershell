######################################################################
#
# This script will find the 10 (default) largest files and then list the
# folders sizes of the c:\ drive (default). The results will be written to a
# formatted text file. At the end of the script is an option to scan and list
# the size of all sub folders within a particular folder, output will be 
# appended to the txt file generated during the initial scan.
#
# Author: Rob Willis 6/15/2016
# Modified: 6/9/2020 by Andrew Newell for use with Datto RMM as component
######################################################################
# RMM Variables for reference
#
# FilesLimit - The number of files to limit the scan to (default 10)
# ScanType - The type of scan method (Root, Folder, Files)
# ScanDrive - The root drive to scan inside
# ScanFolder - Used only with the Folder method, the path relative to the root to scan
# FileSizeThreshold - The minimum file size to include in results. Only applicable to the Files scan method

# Datto RMM error checking user vars
if (([string]::IsNullOrEmpty($env:FilesLimit)) -or (!($env:FilesLimit -match "^\d+$"))){
	#value is empty or null OR is non-numeric
	$env:FilesLimit = 10
}
if (([string]::IsNullOrEmpty($env:FileSizeThreshold)) -or (!($env:FileSizeThreshold -match "^\d+$"))){
	#value is empty or null OR is non-numeric
	$env:FileSizeThreshold = 10MB
}elseif($env:FileSizeThreshold -match "^\d+$"){
	#convert number to MB
	$temp = [int]$env:FileSizeThreshold
	$env:FileSizeThreshold = $temp * 1024 * 1024
}
if ([string]::IsNullOrEmpty($env:ScanDrive)){
	#if empty/null default to C:
	$env:ScanDrive = "C:\"
}elseif(!($env:ScanDrive -match "^.\:$")){
	#missing colon character for drive, add it
	$env:ScanDrive = $env:ScanDrive.Insert($env:ScanDrive.length,":")
}
if($env:ScanDrive.Length -ne 2){
	#invalid drive letter format, assume default
	$env:ScanDrive = "C:"
	Write-Host "Warning: Invalid drive letter format specified, assuming default C:"
}
if(!([string]::IsNullOrEmpty($env:ScanFolder)) -and ($env:ScanFolder -match "(^\\.{1,}$|^.{1,}\\$)")){
	#folder path has leading or trailing \ and needs to be removed
	$env:ScanFolder = $env:ScanFolder.Trim("\\")
}
if ((([string]::IsNullOrEmpty($env:ScanFolder)) -or !(Test-Path -Path "$($env:ScanDrive)\$($env:ScanFolder)")) -and ($env:ScanType -eq "Folder")){
	$env:ScanType = "Root"
	Write-Host "Warning: No path provided for Folder scan type or an invalid path was provided, falling back to Root scan type instead"
}

# Drive to Scan
$diskDrive = $env:ScanDrive
#limit results to this number
$filesLimit = [int]$env:FilesLimit
 
 
###################################
# Do not edit below!
###################################
# Misc settings
# Root location to scan for folder size
$filesLocation = "$diskDrive\"
$rootLocation = $filesLocation
# Minimum file size to include
$fileSize = [int]$env:FileSizeThreshold
 
###################################
# Top Largest Files Scan
###################################
 
Function fileScan {
Write-Host " "
Write-Host "Scanning $filesLocation for the $filesLimit largest files, this process will take a few minutes..."
$largeSizefiles = Get-ChildItem -path $filesLocation -Recurse -Force -ErrorAction SilentlyContinue `
 | Where-Object { ($_.GetType().Name -eq "FileInfo") -and ($_.Length -gt $fileSize) } `
 | Sort-Object -Property Length -Descending `
 | Select-Object @{Name="FileName";Expression={$_.Name}},@{Name="Path";Expression={$_.directory}},@{Name="Size In MB";Expression={ "{0:N0}" -f ($_.Length / 1MB)}} -first $filesLimit
$largeSizefiles | Format-List
}
 
###################################
# Top Largest Folders Scan
###################################
 
Function folderScan {
$subDirectories = Get-ChildItem $rootLocation | Where-Object{($_.PSIsContainer)} | foreach-object{$_.Name}
Write-Host "Calculating folder sizes for $rootLocation,"
Write-Host "this process will take a few minutes..."
Write-Host " "
$folderOutputFixed = @{}
foreach ($i in $subDirectories)
	{
	$targetDir = $rootLocation + $i
	$folderSize = (Get-ChildItem $targetDir -Recurse -Force | Measure-Object -Property Length -Sum).Sum 2> $null
    $folderSizeComplete = "{0:N0}" -f ($folderSize / 1MB) + "MB"
	$folderOutputFixed.Add("$targetDir" , "$folderSizeComplete")
	write-host " Calculating $targetDir..."
}
$folderOutputFixed.GetEnumerator() | sort-Object Name | format-table -autosize
}
 
###################################
# Custom Folder Scan
###################################
 
Function customScan {
$customLocation = "$($env:ScanDrive)\$($env:ScanFolder)"
$subDirectories = Get-ChildItem $customLocation | Where-Object{($_.PSIsContainer)} | foreach-object{$_.Name}
Write-Host " "
Write-Host "Calculating folder sizes for $customLocation,"
Write-Host "this process will take a few minutes..."
"Estimated folder sizes for $customLocation :"
Write-Host " "
$folderOutput = @{}
foreach ($i in $subDirectories)
	{
	$targetDir = $customLocation + "\" + $i
	$folderSize = (Get-ChildItem $targetDir -Recurse -Force | Measure-Object -Property Length -Sum).Sum 2> $null
    $folderSizeComplete = "{0:N0}" -f ($folderSize / 1MB) + "MB" 
	$folderOutput.Add("$targetDir" , "$folderSizeComplete")
    write-host " Calculating $targetDir..."
}
$folderOutput.GetEnumerator() | sort-Object Name | format-table -autosize
}
 
#get start time
$startTime = Get-Date
Write-Host "Starting scan at: $startTime"
#type of scan to perform
if ($env:ScanType -eq "Files"){ fileScan }
if ($env:ScanType -eq "Folder"){ customScan }
if ($env:ScanType -eq "Root"){ folderScan }

#get end time and duration
$endTime = Get-Date
$durationTime = New-TimeSpan -Start $startTime -End $endTime
Write-Host "Scan Finished at: $endTime"
Write-Host "`nDuration of scan took $($durationTime.Days) days, $($durationTime.Hours) hours, $($durationTime.Minutes) minutes and $($durationTime.Seconds) $(if($durationTime.Seconds -eq 1){'second'}else{'seconds'})"
