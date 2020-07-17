#used to calculate a future date 1 year minus 60 days for domain registration

param (
    [string]$inDate
 )
 Function CalcDate($inDate){
    $outDate = $inDate | ConvertFrom-String -Delimiter "/"
    $day = $outDate.P1
    $month = $outDate.P2
    $year = $outDate.P3
    $outDate = ((Get-Date -Month $month -Day $day -Year $year).AddDays(-60))
    $outDate = $outDate.AddYears(1)

    $result = "$($outDate.Month)/$($outDate.Day)/$($outDate.Year)"
    return $result;
}

if ([string]::IsNullOrEmpty($inDate) -or !($inDate -match "^([0-2][0-9]|[3][0-1])\/([0][0-9]|[1][0-2])\/\d{4}$")){
    #if empty or invalid format
    Write-Host "Invalid date provided! Expecting valid date in format: DD/MM/YYYY" -ForegroundColor Red
    return;
}
Write-Host -ForegroundColor Yellow "Assuming date in format: DD/MM/YYYY"
$ExpiryDate = CalcDate($inDate);
Set-Clipboard $ExpiryDate
Write-Host -ForegroundColor Green "Added 1 year minus 60 days to date. Calculated expiry date as: $ExpiryDate"
Write-Host "Saved to clipboard!"

