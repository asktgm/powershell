REM enable or disable login auditing
if %enableLogging% equ true (set logonlogoffaudit="enable")
if %enableLogging% equ false (set logonlogoffaudit="disable")

auditpol.exe /set /Category:"Logon/Logoff" /success:%logonlogoffaudit%
