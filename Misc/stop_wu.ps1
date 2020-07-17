#command line args
param(
    [bool]$auto = $false
)

#3rd party function
Function Set-Owner {
    <#
        .SYNOPSIS
            Changes owner of a file or folder to another user or group.

        .DESCRIPTION
            Changes owner of a file or folder to another user or group.

        .PARAMETER Path
            The folder or file that will have the owner changed.

        .PARAMETER Account
            Optional parameter to change owner of a file or folder to specified account.

            Default value is 'Builtin\Administrators'

        .PARAMETER Recurse
            Recursively set ownership on subfolders and files beneath given folder.

        .NOTES
            Name: Set-Owner
            Author: Boe Prox
            Version History:
                 1.0 - Boe Prox
                    - Initial Version

        .EXAMPLE
            Set-Owner -Path C:\temp\test.txt

            Description
            -----------
            Changes the owner of test.txt to Builtin\Administrators

        .EXAMPLE
            Set-Owner -Path C:\temp\test.txt -Account 'Domain\bprox

            Description
            -----------
            Changes the owner of test.txt to Domain\bprox

        .EXAMPLE
            Set-Owner -Path C:\temp -Recurse 

            Description
            -----------
            Changes the owner of all files and folders under C:\Temp to Builtin\Administrators

        .EXAMPLE
            Get-ChildItem C:\Temp | Set-Owner -Recurse -Account 'Domain\bprox'

            Description
            -----------
            Changes the owner of all files and folders under C:\Temp to Domain\bprox
    #>
    [cmdletbinding(
        SupportsShouldProcess = $True
    )]
    Param (
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [Alias('FullName')]
        [string[]]$Path,
        [parameter()]
        [string]$Account = 'Builtin\Administrators',
        [parameter()]
        [switch]$Recurse
    )
    Begin {
        #Prevent Confirmation on each Write-Debug command when using -Debug
        If ($PSBoundParameters['Debug']) {
            $DebugPreference = 'Continue'
        }
        Try {
            [void][TokenAdjuster]
        } Catch {
            $AdjustTokenPrivileges = @"
            using System;
            using System.Runtime.InteropServices;

             public class TokenAdjuster
             {
              [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
              internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
              ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
              [DllImport("kernel32.dll", ExactSpelling = true)]
              internal static extern IntPtr GetCurrentProcess();
              [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
              internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr
              phtok);
              [DllImport("advapi32.dll", SetLastError = true)]
              internal static extern bool LookupPrivilegeValue(string host, string name,
              ref long pluid);
              [StructLayout(LayoutKind.Sequential, Pack = 1)]
              internal struct TokPriv1Luid
              {
               public int Count;
               public long Luid;
               public int Attr;
              }
              internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
              internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
              internal const int TOKEN_QUERY = 0x00000008;
              internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
              public static bool AddPrivilege(string privilege)
              {
               try
               {
                bool retVal;
                TokPriv1Luid tp;
                IntPtr hproc = GetCurrentProcess();
                IntPtr htok = IntPtr.Zero;
                retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
                tp.Count = 1;
                tp.Luid = 0;
                tp.Attr = SE_PRIVILEGE_ENABLED;
                retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
                retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
                return retVal;
               }
               catch (Exception ex)
               {
                throw ex;
               }
              }
              public static bool RemovePrivilege(string privilege)
              {
               try
               {
                bool retVal;
                TokPriv1Luid tp;
                IntPtr hproc = GetCurrentProcess();
                IntPtr htok = IntPtr.Zero;
                retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
                tp.Count = 1;
                tp.Luid = 0;
                tp.Attr = SE_PRIVILEGE_DISABLED;
                retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
                retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
                return retVal;
               }
               catch (Exception ex)
               {
                throw ex;
               }
              }
             }
"@
            Add-Type $AdjustTokenPrivileges
        }

        #Activate necessary admin privileges to make changes without NTFS perms
        [void][TokenAdjuster]::AddPrivilege("SeRestorePrivilege") #Necessary to set Owner Permissions
        [void][TokenAdjuster]::AddPrivilege("SeBackupPrivilege") #Necessary to bypass Traverse Checking
        [void][TokenAdjuster]::AddPrivilege("SeTakeOwnershipPrivilege") #Necessary to override FilePermissions
    }
    Process {
        ForEach ($Item in $Path) {
            Write-Verbose "FullName: $Item"
            #The ACL objects do not like being used more than once, so re-create them on the Process block
            $DirOwner = New-Object System.Security.AccessControl.DirectorySecurity
            $DirOwner.SetOwner([System.Security.Principal.NTAccount]$Account)
            $FileOwner = New-Object System.Security.AccessControl.FileSecurity
            $FileOwner.SetOwner([System.Security.Principal.NTAccount]$Account)
            $DirAdminAcl = New-Object System.Security.AccessControl.DirectorySecurity
            $FileAdminAcl = New-Object System.Security.AccessControl.DirectorySecurity
            $AdminACL = New-Object System.Security.AccessControl.FileSystemAccessRule('Builtin\Administrators','FullControl','ContainerInherit,ObjectInherit','InheritOnly','Allow')
            $FileAdminAcl.AddAccessRule($AdminACL)
            $DirAdminAcl.AddAccessRule($AdminACL)
            Try {
                $Item = Get-Item -LiteralPath $Item -Force -ErrorAction Stop
                If (-NOT $Item.PSIsContainer) {
                    If ($PSCmdlet.ShouldProcess($Item, 'Set File Owner')) {
                        Try {
                            $Item.SetAccessControl($FileOwner)
                        } Catch {
                            Write-Warning "Couldn't take ownership of $($Item.FullName)! Taking FullControl of $($Item.Directory.FullName)"
                            $Item.Directory.SetAccessControl($FileAdminAcl)
                            $Item.SetAccessControl($FileOwner)
                        }
                    }
                } Else {
                    If ($PSCmdlet.ShouldProcess($Item, 'Set Directory Owner')) {                        
                        Try {
                            $Item.SetAccessControl($DirOwner)
                        } Catch {
                            Write-Warning "Couldn't take ownership of $($Item.FullName)! Taking FullControl of $($Item.Parent.FullName)"
                            $Item.Parent.SetAccessControl($DirAdminAcl) 
                            $Item.SetAccessControl($DirOwner)
                        }
                    }
                    If ($Recurse) {
                        [void]$PSBoundParameters.Remove('Path')
                        Get-ChildItem $Item -Force | Set-Owner @PSBoundParameters
                    }
                }
            } Catch {
                Write-Warning "$($Item): $($_.Exception.Message)"
            }
        }
    }
    End {  
        #Remove priviledges that had been granted
        [void][TokenAdjuster]::RemovePrivilege("SeRestorePrivilege") 
        [void][TokenAdjuster]::RemovePrivilege("SeBackupPrivilege") 
        [void][TokenAdjuster]::RemovePrivilege("SeTakeOwnershipPrivilege")     
    }
}

Function DISABLE_WindowsUpdate{
    #disable windows update and rename the software distribution folder in case there are pending updates
    #also disable BITS
    $swDistPath = "$($env:windir)\SoftwareDistribution"
    $bitsdll = "$($env:windir)\system32\qmgr.dll"
    $wudll = "$($env:windir)\system32\wuaueng.dll"
    $user = Get-WMIObject -class Win32_ComputerSystem | Select-Object username
    $timestamp = Get-Date -UFormat "%y%m%d%S"

    Write-Host -BackgroundColor Yellow -ForegroundColor Black "Disabling windows update service. . ."
    Set-Service wuauserv -StartupType Disabled
    Stop-Service wuauserv -Force
    Write-Host -BackgroundColor Yellow -ForegroundColor Black "Disabling background intelligent transfer service. . ."
    Set-Service BITS -StartupType Disabled
    Stop-Service BITS -Force

    $wusvc = Get-Service -Name wuauserv
    $bitssvc = Get-Service -Name BITS

    if ($bitssvc.StartType -eq "Disabled" -and $bitssvc.Status -eq "Stopped"){
        Write-Host -BackgroundColor Green -ForegroundColor Black "Successfully disabled Background Intelligent Transfer service!"
        Set-Owner -Path $bitsdll -Account $user.username
        Get-Acl $env:USERPROFILE | Set-Acl -Path $bitsdll
        Rename-Item -Path $bitsdll -NewName "qmgr.dll_disabled" -Force
    }else{
        Write-Host -BackgroundColor Red -ForegroundColor Black "Error, could not fully disable background intelligent transfer service. . ."
    }

    if ($wusvc.StartType -eq "Disabled" -and $wusvc.Status -eq "Stopped"){
        Write-Host -BackgroundColor Green -ForegroundColor Black "Successfully disabled Windows Update!"
        Set-Owner -Path $wudll -Account $user.username
        Get-Acl $env:USERPROFILE | Set-Acl -Path $wudll
        Rename-Item -Path $wudll -NewName "wuaueng.dll_disabled" -Force
        Rename-Item -Path $swDistPath -NewName "SoftwareDistribution.old$($timestamp)" -Force
    }else{
        Write-Host -BackgroundColor Red -ForegroundColor Black "Error, could not fully disable Windows Update service. . ."
    }
}

Function ENABLE_WindowsUpdate{
    $dis_bitsdll = "$($env:windir)\system32\qmgr.dll_disabled"
    $dis_wudll = "$($env:windir)\system32\wuaueng.dll_disabled"
    $base_acl_file = "$($env:windir)\system32\SearchIndexer.exe"

    Write-Host -BackgroundColor Yellow -ForegroundColor Black "Attempting to re-enable Windows Update service(s). . ."
    #try bits
    #if windows inadvertently fixed this we don't need to rename
    if (Test-Path "$($env:windir)\system32\qmgr.dll"){
        #regular name exists! don't bother renaming, just delete the old version
        Remove-Item -Force -Path $dis_bitsdll
    }else{
        #Windows didn't fix, proceed normally
        takeown.exe /F $dis_bitsdll | Out-Null
        icacls.exe $dis_bitsdll /setowner "NT SERVICE\TrustedInstaller" | Out-Null
        Rename-Item -Path $dis_bitsdll -NewName "qmgr.dll"
    }
    Get-Acl $base_acl_file | Set-Acl -Path "$($env:windir)\system32\qmgr.dll"

    #permissions reset, try to enable service
    Set-Service BITS -StartupType Automatic
    Start-Service BITS
    $bitssvc = Get-Service -Name BITS

    if ($bitssvc.StartType -eq "Automatic" -and $bitssvc.Status -ne "Stopped"){
        Write-Host -BackgroundColor Green -ForegroundColor Black "Successfully re-enabled BITS!"
    }else{
        Write-Host -BackgroundColor Red -ForegroundColor Black "Error re-enabling BITS. . ."
    }

    #try wuauserv
    #if windows inadvertently fixed this we don't need to rename
    if (Test-Path "$($env:windir)\system32\wuaueng.dll"){
        #regular name exists! don't bother renaming, just delete the old version
        Remove-Item -Force -Path $dis_wudll
    }else{
        #Windows didn't fix, proceed normally
        takeown.exe /F $dis_wudll | Out-Null
        icacls.exe $dis_wudll /setowner "NT SERVICE\TrustedInstaller" | Out-Null
        Rename-Item -Path $dis_wudll -NewName "wuaueng.dll"
    }
    Get-Acl $base_acl_file | Set-Acl -Path "$($env:windir)\system32\wuaueng.dll"

    #permissions reset, try to enable service
    Set-Service wuauserv -StartupType Automatic
    Start-Service wuauserv
    $wusvc = Get-Service -Name wuauserv

    if ($wusvc.StartType -eq "Automatic" -and $wusvc.Status -ne "Stopped"){
        Write-Host -BackgroundColor Green -ForegroundColor Black "Successfully re-enabled WUAUSERV!"
    }else{
        Write-Host -BackgroundColor Red -ForegroundColor Black "Error re-enabling WUAUSERV. . ."
    }

    #determine final outcome
    if ($wusvc.Status -ne "Stopped" -and $bitssvc.Status -ne "Stopped"){
        Write-Host -BackgroundColor Green -ForegroundColor Black "Re-enabling of Windows Update services was successful!"
    }else{
        Write-Host -BackgroundColor Red -ForegroundColor Black "There was an error re-enabling all Windows Update services. . ."
    }
}


#detect if this script was previously applied
if ((Test-Path "$($env:windir)\system32\qmgr.dll_disabled") -or (Test-Path "$($env:windir)\system32\wuaueng.dll_disabled")){
    $already_disabled = $true
}else{
    $already_disabled = $false
}

if ([bool]$auto){
    #run in auto mode
    if ($already_disabled){
        ENABLE_WindowsUpdate
    }else{
        DISABLE_WindowsUpdate
    }
}else{
    #run in regular mode
    $userChoice = $false #create variable
    if ($already_disabled){
        #only offer to re-enable if we detect it's disabled already
        Write-Host -BackgroundColor Black -ForegroundColor Yellow "Detected that Windows Update services are disabled!"
        Switch (Read-Host "Would you like to try to re-enable them? ( Y or N ) ")
        { 
            Y {Write-host "Okay!" -ForegroundColor Yellow; $userChoice=$true} 
            N {Write-Host "We won't try to re-enable services. . ."; $userChoice=$false} 
            Default {Write-Host "defaulting to not try to re-enable services. . ."; $userChoice=$false}
        }
        if ($userChoice){
            ENABLE_WindowsUpdate
        }
    }else{
        Switch (Read-Host "Would you like to try to disable Windows Update completely? ( Y or N ) ")
        { 
            Y {Write-host "Okay!" -ForegroundColor Yellow; $userChoice=$true} 
            N {Write-Host "We won't try to disable windows update. . ."; $userChoice=$false} 
            Default {Write-Host "defaulting to not try to windows update. . ."; $userChoice=$false}
        }
        if($userChoice){
            DISABLE_WindowsUpdate
        }
    }
}
