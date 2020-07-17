#monitor to check if huntress is installed

function Output-dRMM-Result{
    #exit value 1 is alert, 0 is no alert
    Param([bool]$installStatus, $diagMsg, [int16]$exitval)
    Write-Host "<-Start Result->"
    Write-Host "installed=$installStatus"
    Write-Host "<-End Result->"
    if ($list){
        Write-Host "<-Start Diagnostic->"
        Write-Host $diagMsg
        Write-Host "<-End Diagnostic->"
    }
    exit $exitval
}

$huntressInstallDir = "$($env:ProgramFiles)\Huntress"
$huntressFile = "HuntressAgent.exe"

if (Test-Path -Path $huntressInstallDir){
    #folder exists, now check for the exe to be sure
    if (Test-Path -Path "$huntressInstallDir\$huntressFile"){
        #file is found
        Output-dRMM-Result -installStatus $true -diagMsg "Huntress appears to be installed correctly." -exitval 0
    }else{
        Output-dRMM-Result -installStatus $false -diagMsg "Huntress install folder found but exe is missing!" -exitval 1
    }
}else{
    #folder not found
    Output-dRMM-Result -installStatus $false -diagMsg "Huntress does not appear to be installed." -exitval 1
}