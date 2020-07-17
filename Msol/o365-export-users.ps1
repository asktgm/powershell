#export all users for a client and their assigned licenses


Add-Type -AssemblyName System.Windows.Forms

$foldername = New-Object System.Windows.Forms.FolderBrowserDialog
$foldername.rootfolder = "Desktop"
$foldername.Description = "Choose where to save the CSV file"
$foldername.ShowDialog()
Write-Host -ForegroundColor Yellow "Saving to $($foldername.SelectedPath)"

Connect-MsolService
if($? -eq $false){
    Write-Host -ForegroundColor Red "There was an error connecting to the Office 365 tenant (wrong password?)"
}else{
    $cd = Get-Date
    $cd = "$($cd.Month)-$($cd.Day)-$($cd.Year)-$($cd.Hour)$($cd.Minute)$($cd.Second)"
    $fp = "$($foldername.SelectedPath)\O365-UserExport.$($cd).csv"
    Get-MsolUser -all |Select-Object UserPrincipalName,DisplayName,isLicensed,{$_.Licenses.AccountSkuId} | Export-Csv -Path $fp -NoTypeInformation
    if (Test-Path -Path $fp){
        Write-Host -ForegroundColor Green "Exported data to $fp"
    }else{
        Write-Host -ForegroundColor Red "There was an error exporting the file..."
    }
    
}