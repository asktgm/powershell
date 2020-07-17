#monitor to check if infocyte is installed

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

$infocyteInstallDir = "$($env:ProgramFiles)\Infocyte\Agent"
$infocyteFile = "agent.windows.exe"

if (Test-Path -Path $infocyteInstallDir){
    #folder exists, now check for the exe to be sure
    if (Test-Path -Path "$infocyteInstallDir\$infocyteFile"){
        #file is found
        Output-dRMM-Result -installStatus $true -diagMsg "Infocyte appears to be installed correctly." -exitval 0
    }else{
        Output-dRMM-Result -installStatus $false -diagMsg "Infocyte install folder found but exe is missing!" -exitval 1
    }
}else{
    #folder not found
    Output-dRMM-Result -installStatus $false -diagMsg "Infocyte does not appear to be installed." -exitval 1
}