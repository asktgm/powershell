#exchange online powershell script
#use to get connected without copying everything
#doesn't work with MFA!!!

function global:exit-exops{Remove-PSSession $Session;exit;}

$UserCredential = Get-Credential

$global:Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection -ErrorAction SilentlyContinue
if ($Session -ne $null){ Import-PSSession $Session; Clear-Host; Write-Host -ForegroundColor Green "Session imported!"; Write-Host -ForegroundColor Yellow "Use exit-exops to destroy the session when finished!" }else{ Write-Host -ForegroundColor Red "There was an error creating the session." }
