# DattoRMM PowerShell Script to create a custom admin user
# Variables:
# AccountName - name of the account
# AccountPasswd - account password
# IsAdmin - whether the account should be an admin
# Hidden - whether the account should appear on the login screen
# Expires - if the account should expire
# ExpireDate - the date the account expires if set to do so

#Update data types for user variables
if ($env:IsAdmin -eq "Yes") {
	$env:IsAdmin  = $true
	Write-Host "Info: Setting account as admin"
}elseif ($env:IsAdmin -eq "No") {
	$env:IsAdmin = $false
	Write-Host "Info: Setting account as non-admin"
}
if ($env:Hidden -eq "Yes") {
	$env:Hidden = $true
	Write-Host "Info: Setting account as hidden"
}elseif ($env:Hidden -eq "No") {
	$env:Hidden = $false
	Write-Host "Info: Setting account as visible"
}
if ($env:Expires -eq "Yes") {
	$env:Expires = $true
	Write-Host "Info: Setting account to expire"
}elseif ($env:Expires -eq "No") {
	$env:Expires = $false
	Write-Host "Info: Setting account with no expiry"
}
if (!($env:ExpireDate -match "^\d{1,4}\-\d{1,2}\-\d{1,2}$") -and ($env:Expires)) {
	#expecting format YYYY-MM-DD
	Write-Host "Error: Expiry date in invalid format, exiting. . ."
	return;
}elseif (($env:ExpireDate -match "^\d{1,4}\-\d{1,2}\-\d{1,2}$") -and ($env:Expires)) {
	Write-Host "Info: Setting account to expire on $($env:ExpireDate)"
}

#now create the account
Write-Host "`nCreating account. . ."
cmd.exe /C "net user $env:AccountName $env:AccountPasswd /add" | Out-Null
Write-Host "Setting password to never expire. . ."
Get-WmiObject Win32_UserAccount -Filter "Name = '$env:AccountName'" | Set-WmiInstance -Arguments @{PasswordExpires=$false} | Out-Null
if($env:IsAdmin){
	Write-Host "Adding $env:AccountName to admins group. . ."
	Add-LocalGroupMember -Group "Administrators" -Member $env:AccountName
}
if($env:Hidden){
	Write-Host "Hiding account. . ."
	reg.exe ADD "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" /f /v $env:AccountName /t REG_DWORD /d 0 | Out-Null
	#check for EnumerateAdministrators policy is configured properly
}
if($env:Expires){
	Write-Host "Applying account expiration date"
	Set-LocalUser -AccountExpires (Get-Date $env:ExpireDate) -Name $env:AccountName
}

if($env:IsAdmin -and $env:Hidden){
	#change policy to allow other admins to authenticate UAC prompts!
	Write-Host "Checking that UAC allows authentication as other user. . ."
	$regPolPath = "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies"
	if (!(Test-Path -Path $regPolPath)){
		#key doesn't exist, create it
		Write-Host "Creating registry key. . ."
		New-Item -Path $regPolPath -Name "CredUI" -Force
	}
	if (Get-ItemProperty -Path "$($regPolPath)\CredUI" -Name EnumerateAdministrators){
		#value is set, is it correct?
		if ((Get-ItemProperty -Path "$($regPolPath)\CredUI" -Name EnumerateAdministrators).EnumerateAdministrators -ne 0){
			#change it to 0
			Write-Host "Setting key value for policy. . ."
			Set-ItemProperty -Path "$($regPolPath)\CredUI" -Name EnumerateAdministrators -Value 0
		}
	}else{
		#value doesn't exist, set it
		Write-Host "Creating and setting key value for policy. . ."
		New-ItemProperty -Path "$($regPolPath)\CredUI" -Name "EnumerateAdministrators" -PropertyType "DWord" -Value 0 | Out-Null
	}
}