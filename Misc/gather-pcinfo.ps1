#gather information for non-rmm PC's
#hardware specs
#age of machine
#installed programs
#startup programs
#disk usage
#memory usage
#OS version
#problem application versions and app outdated?

$infoObject = New-Object -TypeName psobject

$PCINFO = Get-ComputerInfo

#---HARDWARE RELATED---
#CPU Name(s)
$cpuName = @()
foreach ($item in $PCINFO.CsProcessors){ $cpuName += $item.Name }
#BIOS age
$biosDate = $PCINFO.BiosReleaseDate.ToString("yyyy/MM/dd")
#Memory
#  total
$memTotal = 0.0
foreach ($item in (Get-WmiObject -Class "win32_physicalmemory" -Namespace "root\CIMV2").Capacity){
    $memTotal += $item
}
$memTotal = $memTotal / 1GB
#  available
$memAvail = ((Get-Counter '\Memory\Available Bytes').CounterSamples.CookedValue) / 1GB
#  used
$memUsed = $memTotal - $memAvail
$memUsed = [math]::Round($memUsed,2)
$memAvail = [math]::Round($memAvail,2)
#Disk
$diskInfo = Get-WmiObject -Class Win32_logicaldisk | Where-Object {$null -ne $_.Size} |Select-Object DeviceID,FreeSpace,Size,VolumeName
$diskTable = $diskInfo | Format-Table `
@{
    label="Drive";Expression={
        $_.DeviceID
    }
},`
@{
    label="Free (GB)";Expression={
        [math]::Round(($_.FreeSpace / 1GB),2)
    }
},`
@{
    label="Capacity (GB)";Expression={
        [math]::Round(($_.Size / 1GB),2)
    }
},`
@{
    label="Percent Used";Expression={
        [math]::round((100.00 - (($_.FreeSpace / $_.Size) * 100)),2)
    }
}
#Software
#method sourced from https://devblogs.microsoft.com/scripting/use-powershell-to-quickly-find-installed-software/
$installedSoftware = @()
$UninstallKey="SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
$reg=[microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine',$computername) 
$regkey=$reg.OpenSubKey($UninstallKey) 
$subkeys=$regkey.GetSubKeyNames() 
foreach($key in $subkeys){
    $thiskey=$UninstallKey+"\\"+$key
    $thisSubKey=$reg.OpenSubKey($thiskey)
    $DisplayName=$thisSubKey.GetValue("DisplayName")
    if (!([string]::IsNullOrEmpty($DisplayName))){$installedSoftware += $DisplayName}
}
#---SOFTWARE RELATED---
#OS Name
$osName = $PCINFO.OsName
#OS architecture
$osArc = $PCINFO.OsArchitecture
#PC name
$pcName = $PCINFO.CsCaption

#populate custom object with info
$infoObject | Add-Member -MemberType NoteProperty -Name 'Operating System' -Value $osName
$infoObject | Add-Member -MemberType NoteProperty -Name 'OS Architecture' -Value $osArc
$infoObject | Add-Member -MemberType NoteProperty -Name 'CPU' -Value $cpuName
$infoObject | Add-Member -MemberType NoteProperty -Name 'BIOS Age' -Value $biosDate
$infoObject | Add-Member -MemberType NoteProperty -Name 'PC Name' -Value $pcName
$infoObject | Add-Member -MemberType NoteProperty -Name 'Storage Info' -Value ($diskTable)
$infoObject | Add-Member -MemberType NoteProperty -Name 'Memory Total' -Value $memTotal
$infoObject | Add-Member -MemberType NoteProperty -Name 'Memory Used' -Value $memUsed
$infoObject | Add-Member -MemberType NoteProperty -Name 'Memory Available' -Value $memAvail
$infoObject | Add-Member -MemberType NoteProperty -Name 'Installed Software' -Value $installedSoftware


$infoObject | Select-Object 'Operating System','OS Architecture','CPU','BIOS Age','PC Name','Memory Total','Memory Used','Memory Available'
Write-Host "Disk Info:"
$infoObject.'Storage Info'
Write-Host "Installed Software:"
$infoObject.'Installed Software'