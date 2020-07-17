# should scan a given location for a given extension type
# and raise an alert if anything is found!
# originally based on info from https://www.computerperformance.co.uk/ezine/ezine133/#Example_1_-_Find_all_dlls_in_the_Windows/System32_folder.

#Use this function to generate results in dRMM
function Output-dRMM-Result{
    #exit value 1 is alert, 0 is no alert
    Param([string]$foundFiles, $list, [int16]$exitval)
    Write-Host "<-Start Result->"
    Write-Host "foundFiles=$($foundFiles)"
    Write-Host "<-End Result->"
    Write-Host "Files found with extension $($scanExtension):"
    if ($list){
        Write-Host "<-Start Diagnostic->"
        foreach($item in $list)
        {
            Write-Host $item.FullName
        }
        Write-Host "<-End Diagnostic->"
    }
    exit $exitval
}

#convert user provided data to working variables
$scanRootPath = $env:RootPathToScan
$scanExtension = $env:FileExtension

#perform the scan
if ($scanRootPath.ToLower() -eq "all"){
    #if we're scanning all drives
    #gather all valid drive letters on system
    $allDrives = (Get-PSDrive).Name -match '^[a-z]$'
    $allDrives = $allDrives | ForEach-Object {"$_`:\"} #appends the :\ to each drive letter
    $dir = $null
    foreach($drive in $allDrives){ $dir += Get-ChildItem -Path $drive -Recurse -ErrorAction SilentlyContinue } #scans each directory on each drive letter
    $fileList = $dir | Where-Object {$_.extension -eq $scanExtension} #scans each file
}else{
    #standard scan
    $dir = $null
    #split up multiple items if they exist (comma delimited)
    $scanRootPath = $scanRootPath -split ',+'
    #actually scan now
    foreach($dirLocation in $scanRootPath){ $dir += Get-ChildItem -Path $dirLocation -Recurse -ErrorAction SilentlyContinue } #scans each directory on each drive letter
    $fileList = $dir | Where-Object {$_.extension -eq $scanExtension} #scans each file
}


#if anything is found output a message and exit with fail code
if ($fileList){
    Output-dRMM-Result -foundFiles $true -list $fileList -exitval 1
    <# Write-Host "Found some files, here are their paths:"
    foreach($e in $fileList){Write-Host $e.FullName} #>
}else{
    Output-dRMM-Result -foundFiles $false -exitval 0
}