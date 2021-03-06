# **************************************************************************************
# Name:         Bulk NSLOOKUP utility
# Description:  Originally made by Nick Shaw (11/25/13), updated and modified by Andrew
#               Newell (12/05/2018). If invoked without any arguements will run in 
#               interactive mode and request user input. If invoked with command line
#               arguments can automatically run. Results are saved in a CSV file.
# Version:      1.2 (2020-06-04)
# Notes:        added some more resiliency and ability to pass comma separated list as
#               an argument as well instead of file only
# **************************************************************************************


#command line args
param(
    [string]$file = "nil",
    [string]$filterarg = $null
)


function GetFullPath($baseFile){
    #use to resolve a full path to file
    if (Test-Path -Path $baseFile){
        #were we given the full path?
        $fullpath = Resolve-Path -Path $baseFile
    }elseif (Test-Path -Path ".\$($file)") {
        #check for current directory, maybe they assumed current dir?
        $fullpath = Resolve-Path -Path ".\$($baseFile)"
    }else{
        $fullpath = $null
        #Write-Host "Unable to resolve the path to file!"
    }
    return $fullpath
}
Function Get-FileName($initialDirectory){
 [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
 Out-Null

 $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
 $OpenFileDialog.initialDirectory = $initialDirectory
 $OpenFileDialog.filter = "All files (*.*)| *.*"
 $OpenFileDialog.ShowDialog() | Out-Null
 $OpenFileDialog.filename
}
Function LookupHost($hostCollection, [string]$recordType){
    $validRecords = @("A","AAAA","CNAME","MX","NS","PTR","SOA","SRV","TXT")
    if ([string]::IsNullOrWhiteSpace($recordType) -or !($validRecords.Contains($recordType))){
        $recordType = "NS"
        Write-Host -ForegroundColor Yellow "WARNING: No valid record type provided, assuming NS record type by default."
    }
    $totalHosts = $hostCollection.length
    $hostCount = 1
    $result = @()
    foreach ($individualHost in $hostCollection)
    {
        Write-Host -ForegroundColor Yellow "Looking up host $hostCount of $totalHosts"
        $hostData = Resolve-DnsName -Name $individualHost -Type $recordType -NoHostsFile -DnsOnly -ErrorAction SilentlyContinue
        if (!$hostData){
            # lookup error
            Write-Host -ForegroundColor Red "Error performing looking for $individualHost"
        }else{
            #special handling for A, AAAA records
            if ($recordType -eq "A" -or $recordType -eq "AAAA"){$filteredResult = $hostData | Select-Object Name,IPAddress <# only include this data #>}
            #special handling for MX records
            if ($recordType -eq "MX"){$filteredResult = $hostData | Select-Object Name,NameExchange <# only include this data #>}
            #special handling for CNAME, NS, PTR records
            if (($recordType -eq "CNAME") -or ($recordType -eq "NS") -or ($recordType -eq "PTR")){$filteredResult = $hostData | Select-Object Name,NameHost <# only include this data #>}
            #special handling for SOA records
            if ($recordType -eq "SOA"){$filteredResult = $hostData | Select-Object Name,PrimaryServer <# only include this data #>}
            #special handling for SRV records
            if ($recordType -eq "SRV"){$filteredResult = $hostData | Select-Object Name,NameTarget <# only include this data #>}
            #special handling for TXT records
            if ($recordType -eq "TXT"){$filteredResult = $hostData | Select-Object Name,Strings <# only include this data #>}

            $result += $filteredResult
        }
        $hostCount += 1 
    }
    return $result;
}


#MAIN SCRIPT
Clear-Host
$hostlistFilePath = split-path -parent $MyInvocation.MyCommand.Definition
$hostlistFilePath = "$($hostlistFilePath)\hostlist.txt"
#ask if they want to use the hostfile.txt
$userQuestion = Read-Host -Prompt "Do you want to manually enter the domains, or use the hostlist.txt file?`n(If using the hostlist.txt file, it needs to be located in the same directory as this script)`n`n`t1 - Manual Entries`n`t2 - Use hostlist.txt`n`nEnter your choice"
Switch ($userQuestion){
    1 {$userChoice = "manual"}
    2 {$userChoice = "hostlist"}
    Default {Write-Host "`nInvalid entry, using manual entry instead"; $userChoice = "manual"}
}
if ($userChoice -eq "manual"){
    #MANUAL LIST OF DOMAINS
    $userHosts = Read-Host -Prompt "Enter hosts to lookup (comma separated, no spaces)"
    $userHosts = $userHosts.Split("{,}") #format the host list to be used

    $userFilterNS = Read-Host -Prompt "Enter any nameservers to filter out (comma separated, no spaces - leave blank for none)"
    $userFilterNS = $userFilterNS.Split("{,}") #format the filter list to be used

    $recordLookupType = Read-Host -Prompt "Enter the record type to lookup"
    if (!([string]::IsNullOrWhiteSpace($recordLookupType))){$recordLookupType = $recordLookupType.ToUpper()}
    
    #lookup data
    $dnsResults = LookupHost -hostCollection $userHosts -recordType $recordLookupType
    #filter out results if possible
    foreach($filter in $userFilterNS){
        $dnsResults = $dnsResults | Where-Object {$_.NameHost -ne $filter}
    }

    #save results
    $resultFile = "$(Get-Date -UFormat '%Y-%m-%d-%H%M%S')_DNSResults.csv"
    $dnsResults | Export-Csv -Path $resultFile -NoTypeInformation -Encoding UTF8

    if (($null -ne $resultFile) -And (Test-Path $resultFile)){Write-Host -BackgroundColor Green "Complete! Results saved in $($resultFile)"}
}elseif($userChoice -eq "hostlist"){
    #USE HOSTLIST FILE FOR LOOKUPS
    if (Test-Path -Path $hostlistFilePath){
        $hostlistFilePath = Get-Content($hostlistFilePath)

        $userFilterNS = Read-Host -Prompt "Enter any nameservers to filter out (comma separated, no spaces - leave blank for none)"
        $userFilterNS = $userFilterNS.Split("{,}") #format the filter list to be used

        $recordLookupType = Read-Host -Prompt "Enter the record type to lookup"
        if (!([string]::IsNullOrWhiteSpace($recordLookupType))){$recordLookupType = $recordLookupType.ToUpper()}

        #lookup data
        $dnsResults = LookupHost -hostCollection $hostlistFilePath -recordType $recordLookupType
        foreach($filter in $userFilterNS){
            $dnsResults = $dnsResults | Where-Object {$_.NameHost -ne $filter}
        }

        #save results
        $resultFile = "$(Get-Date -UFormat '%Y-%m-%d-%H%M%S')_DNSResults.csv"
        $dnsResults | Export-Csv -Path $resultFile -NoTypeInformation -Encoding UTF8
        if (($null -ne $resultFile) -And (Test-Path $resultFile)){Write-Host -BackgroundColor Green -ForegroundColor Black "Complete! Results saved in $($resultFile)"; ping.exe -n 4 localhost | Out-Null}
    }else{
        Write-Host -ForegroundColor Red "The hostlist.txt file couldn't be located. Exiting..."
        exit;
    }
}else{
    Write-Host -ForegroundColor Red "Something went wrong and we can't continue"
    exit;
}








#THIS SECTION WAS REMOVED, I PROBABLY WON'T COME BACK TO FIX IT BUT IT'S HERE JUST IN CASE!

<# if((($file -eq "nil") -Or ($null -eq $file)) -Or (!(GetFullPath($file)))){
    #interactive mode - no file so ask in script for hosts
    if(($null -ne $file) -and ($file.Length -gt 0)){
        #assume first argument passed was actually domains instead of a file!
        $userHosts = $file.Split("{,}")
    }else{
        $userHosts = Read-Host -Prompt "Enter hosts to lookup (comma separated, no spaces)"
        $userHosts = $userHosts.Split("{,}") #format the host list to be used
    }
    if(($null -ne $filterarg) -and ($filterarg.Length -gt 0)){
        #assuming second arg was provided for filtering!
        $userFilterNS = $filterarg.Split("{,}") #format the filter list to be used
    }else{
        $userFilterNS = Read-Host -Prompt "Enter any nameservers to filter out (comma separated, no spaces - leave blank for none)"
        $userFilterNS = $userFilterNS.Split("{,}") #format the filter list to be used
    }

    #DEBUG BEGIN
    Write-Host $userHosts
    Write-Host $userFilterNS
    pause
    #DEBUG END
    #lookup data
    $dnsResults = LookupHost($userHosts)
    #filter out results if possible
    foreach($filter in $userFilterNS){
        $dnsResults = $dnsResults | Where-Object {$_.NameHost -ne $filter}
    }

    #save results
    $resultFile = "$(Get-Date -UFormat '%Y-%m-%d-%H%M%S')_DNSResults.csv"
    $dnsResults | Export-Csv -Path $resultFile -NoTypeInformation -Encoding UTF8
}elseif(GetFullPath($file)){
    #(semi)non-interactive mode - arg was given so try to use it and don't prompt for any extra data
    $filePath = GetFullPath($file)
    $filePath = Get-Content($filePath)

    if (!$filterarg){
        #did we get the second CL arg for filters?
        $filterarg = Read-Host -Prompt "Enter any nameservers to filter out (comma separated, no spaces - leave blank for none)"
        $filterarg = $filterarg.Split("{,}") #format the filter list to be used
    }elseif($filterarg.Length -gt 0){
        #format the CL arg to be used for filtering
        $filterarg = $filterarg.Split("{,}")
    }
    
    #lookup data
    $dnsResults = LookupHost($filePath)
    #filter out results if possible
    foreach($filter in $filterarg){
        $dnsResults = $dnsResults | Where-Object {$_.NameHost -ne $filter}
    }

    #save results
    $resultFile = "$(Get-Date -UFormat '%Y-%m-%d-%H%M%S')_DNSResults.csv"
    $dnsResults | Export-Csv -Path $resultFile -NoTypeInformation -Encoding UTF8
}else{
    Write-Host -ForegroundColor Red -BackgroundColor Black "something isn't right, we can't continue based on provided command line args! Read the manual!!"
} #>