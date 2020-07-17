param (
    [int]$inNum1 = 0,
    [int]$inNum2 = 0
 )

if (($inNum1 -eq 0) -or ($inNum2 -eq 0)){
    Write-Host "invalid entry provided" -ForegroundColor Red
    exit;
}else{
    $inNum1 -= 1
    $inNum2 -= 1
    $val = "thisisavalue"
    
    $res = "$($val.Substring($inNum1,1))$($val.Substring($inNum2,1))"
    Write-Host $res
    Set-Clipboard $res

}

