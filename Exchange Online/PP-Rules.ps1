Clear-Host
#ProofPoint transport rule creation
#variables
$lastUpdate = Get-Date "July 6 2020" -Format D
$ppeWebPage = "https://help.proofpoint.com/Proofpoint_Essentials/Email_Security/Administrator_Topics/000_gettingstarted/020_connectiondetails"
$curdate = Get-Date -Format D
$ruleName = "Restrict delivery to ProofPoint only"
$ruleComment = "Prevent spammers from bypassing filtering and delivering direct to Office 365 endpoint. `nLast updated on $curdate"
$inConnName = "Proofpoint Essentials Inbound Connector"
$inConnDesc = "Inbound connector for Proofpoint Essentials. Last modified $curdate"
$inConnPrompt = @"
Options for the connector:
`t`t1 - Update the connector
`t`t2 - Leave the connector enabled and don't update it
`t`t3 - Leave the connector and disable it 
`tIf you choose to remove the connector you may want to enable it immediately later in this script 
`tIt is generally safest to leave the connector and disable it if you're not sure
`tWhat do you want to do?
"@
$outConnName = "Proofpoint Essentials Outbound Connector"
$outConnDesc = "Outbound connector for Proofpoint Essentials. Last modified $curdate"
$outConnPrompt = @"
Options for the connector:
`t`t1 - Update the connector
`t`t2 - Leave the connector enabled and don't update it
`t`t3 - Leave the connector and disable it 
`tIf you choose to remove the connector you may want to enable it immediately later in this script 
`tIt is generally safest to leave the connector and disable it if you're not sure
`tWhat do you want to do?
"@

if (!((Get-PSSession).ConfigurationName -like "Microsoft.Exchange")){
    Write-Host -ForegroundColor Red "You don't appear to be connected to an Exchange Online PowerShell session!"
    Write-Host -ForegroundColor Red "Connect to a session first then run this script again!"
    return;
}
function Get-ProofPointIPs{
    #scrape the IP's from ProofPoint help page
    $iplist = @()
    $webReq = (Invoke-WebRequest -Uri $ppeWebPage).ParsedHtml.body.outerText
    Select-String "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/24" -InputObject $webReq -AllMatches | ForEach-Object {$iplist += $_.Matches.Value}
    if ($iplist.Length -gt 0){
        return $iplist
        
    }else{
        throw "Failed to scrape IP's from website"
    }
}
function Get-ProofPointSmartHost{
    $webReq = (Invoke-WebRequest -Uri $ppeWebPage).ParsedHtml.body.outerText
    if ($webReq -match "(outbound-us\d\.ppe-hosted\.com)"){
        $sh = $matches[1]
        return $sh
    }else{
        throw "Failed to scrape SmartHost from website"
    }
}

Write-Host -ForegroundColor Yellow "This script was last updated $lastUpdate."
Write-Host "Attempting to retreive ProofPoint connection info from the web..."
try{
    $iplist = Get-ProofPointIPs
    $ppeSmartHost = Get-ProofPointSmartHost
}catch{
    Write-Host -ForegroundColor Red "ERROR: $_"
    return
}
Write-Host -ForegroundColor Green -NoNewline "Successfully scraped $($iplist.Length) IP's and SmartHost "
Write-Host -ForegroundColor DarkRed -NoNewline "$ppeSmartHost"
Write-Host -ForegroundColor Green " from web"

Write-Host -ForegroundColor Black -BackgroundColor Yellow "Please verify the IP's look correct by visiting the following page:"
Write-Host -ForegroundColor White -BackgroundColor Black "$ppeWebPage"
Write-Host "Press any key to proceed and list the scraped IP's. . ."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
foreach ($ip in $iplist){
    Write-Host -ForegroundColor White -BackgroundColor Black $ip
}

$userPrompt = ""
while ($userPrompt.ToUpper() -ne "Y" -and $userPrompt -ne "N"){
    $userPrompt = Read-Host "Confirm you wish to proceed with the script - [Y]es or [N]o"
    Switch ($userPrompt.ToUpper())
    {
        Y { Write-Host -ForegroundColor Green "Proceeding. . ." }
        N { Write-Host -ForegroundColor Yellow "Exiting script. . ."; return; }
        default { Write-Host -ForegroundColor Yellow "Invalid response, try again. . ." }
    }
}

Write-Host -ForegroundColor Yellow "Creating Exchange Mail Flow rule. . ."
if (Get-TransportRule $ruleName -EA SilentlyContinue){
    Write-Host -ForegroundColor Yellow "Found existing rule in tenant! This rule will be updated instead."
    Remove-TransportRule -Identity $ruleName -Confirm:$false
}
#create lockdown rule
New-TransportRule -Name $ruleName -Comments $ruleComment -Enabled $false -Mode Enforce -FromScope NotInOrganization -DeleteMessage $true -ExceptIfSenderIpRanges $iplist -EA SilentlyContinue | Out-Null

#create Inbound Connector
if (Get-InboundConnector -Identity $inConnName -EA SilentlyContinue){
    #inbound connector exists
    if ((Get-InboundConnector -Identity $inConnName).Enabled){
        Write-Host -ForegroundColor Yellow "Found existing inbound connector that is already enabled!"
        $userPrompt = ""
        while ($userPrompt -ne "1" -and $userPrompt -ne "2" -and $userPrompt -ne "3"){
            $userPrompt = Read-Host $inConnPrompt
            Switch ($userPrompt)
            {
                1{ 
                    Write-Host -ForegroundColor Yellow "Updating the connector"
                    Remove-InboundConnector -Identity $inConnName -Confirm:$false
                    New-InboundConnector -ConnectorType Partner -Enabled $false -SenderIPAddresses $iplist -Name $inConnName -Comment $inConnDesc -RequireTls $true -SenderDomains "smtp:*;1" | Out-Null
                }
                2{
                    Write-Host -ForegroundColor Yellow "Leaving the connector enabled and not updating it. . ."
                }
                3{
                    Write-Host -ForegroundColor Yellow "Leaving the connector and disabling it. . ."
                    Set-InboundConnector -Identity $inConnName -Enabled $false -Confirm:$false
                }
                default { Write-Host -ForegroundColor Red "Invalid response, try again. . ." }
            }
        }
    }else{
        Write-Host -ForegroundColor Yellow "Found existing inbound connector not enabled. This will be updated instead"
        Remove-InboundConnector -Identity $inConnName -Confirm:$false
        New-InboundConnector -ConnectorType Partner -Enabled $false -SenderIPAddresses $iplist -Name $inConnName -Comment $inConnDesc -RequireTls $true -SenderDomains "smtp:*;1" | Out-Null
    }
}else{
    Write-Host -ForegroundColor Yellow "No existing inbound connector found, creating one. . ."
    New-InboundConnector -ConnectorType Partner -Enabled $false -SenderIPAddresses $iplist -Name $inConnName -Comment $inConnDesc -RequireTls $true -SenderDomains "smtp:*;1" | Out-Null
}

#create Outbound Connector
if (Get-OutboundConnector -Identity $outConnName -EA SilentlyContinue){
    #outbound connector exists
    if ((Get-OutboundConnector -Identity $outConnName).Enabled){
        #existing and enabled
        Write-Host -ForegroundColor Yellow "Found existing inbound connector that is already enabled!"
        $userPrompt = ""
        while ($userPrompt -ne "1" -and $userPrompt -ne "2" -and $userPrompt -ne "3"){
            $userPrompt = Read-Host $outConnPrompt
            Switch ($userPrompt)
            {
                1{ 
                    Write-Host -ForegroundColor Yellow "Updating the connector"
                    Remove-OutboundConnector -Identity $inConnName -Confirm:$false
                    New-OutboundConnector -Enabled $false -Name $outConnName -Comment $outConnDesc -SmartHosts $ppeSmartHost `
                    -TlsSettings CertificateValidation -ConnectorType Partner -ConnectorSource Default -RecipientDomains "*" -UseMXRecord $false | Out-Null
                }
                2{
                    Write-Host -ForegroundColor Yellow "Leaving the connector enabled and not updating it. . ."
                }
                3{
                    Write-Host -ForegroundColor Yellow "Leaving the connector and disabling it. . ."
                    Set-OutboundConnector -Identity $outConnName -Enabled $false -Confirm:$false
                }
                default { Write-Host -ForegroundColor Red "Invalid response, try again. . ." }
            }
        }
    }else{
        Write-Host -ForegroundColor Yellow "Found existing outbound connector not enabled. This will be updated instead"
        Remove-OutboundConnector -Identity $outConnName -Confirm:$false
        New-OutboundConnector -Enabled $false -Name $outConnName -Comment $outConnDesc -SmartHosts $ppeSmartHost `
        -TlsSettings CertificateValidation -ConnectorType Partner -ConnectorSource Default -RecipientDomains "*" -UseMXRecord $false | Out-Null
    }
}else{
    Write-Host -ForegroundColor Yellow "No existing outbound connector found, creating one. . ."
    New-OutboundConnector -Enabled $false -Name $outConnName -Comment $outConnDesc -SmartHosts $ppeSmartHost `
    -TlsSettings CertificateValidation -ConnectorType Partner -ConnectorSource Default -RecipientDomains "*" -UseMXRecord $false | Out-Null
}

#modify connection filtering
#get conenction filter IP list
$curIPAllowList = (Get-HostedConnectionFilterPolicy).IPAllowList
$curIPAllowList = [System.Collections.ArrayList]$curIPAllowList #cast to arraylist for editing
#determine differences for connection filter IPs
foreach($item in $iplist){
    $curIPAllowList.Remove($item) #remove duplicates
}
#did we find non-pp ip's in the connection filter?
if ($curIPAllowList.Count -ne 0){
    Write-Host -ForegroundColor Yellow "Info: Found non-ProofPoint IP's in connection filter list:"
    $curIPAllowList | ForEach-Object {Write-Host -ForegroundColor White -BackgroundColor Black $_}
    $userPrompt = ""
    while($userPrompt.ToUpper() -ne "A" -and $userPrompt.ToUpper() -ne "R"){
        $userPrompt = Read-Host "Do you want to [A]ppend these to the list or [R]emove them?"
        Switch ($userPrompt.ToUpper())
        {
            A { Write-Host -ForegroundColor Yellow "Appending non-ProofPoint IP's to connection filter. . ."; }
            R { Write-Host -ForegroundColor Yellow "Removing non-ProofPoint IP's from connection filter. . ."; $curIPAllowList = @() }
            default { Write-Host -ForegroundColor Yellow "Invalid response, try again. . ." }
        }
    }
}
foreach($item in $iplist){
    $curIPAllowList += $item #rebuild array list adding iplist entries
}
$iplist = $curIPAllowList #update variable
Write-Host -ForegroundColor Yellow "Updating connection filter allow IP's. . ."
Set-HostedConnectionFilterPolicy "Default" -IPAllowList $iplist

#ask if rules should be enabled or not
if (Get-TransportRule $ruleName -EA SilentlyContinue){
    Write-Host -ForegroundColor Green "Confirmed exchange mail flow rule has been created!"
    $userPrompt = ""
    while ($userPrompt.ToUpper() -ne "Y" -and $userPrompt -ne "N"){
        $userPrompt = Read-Host "Exchange Mail Flow Rules are disabled by default, do you want to enable them now? [Y]es or [N]o"
        Switch ($userPrompt.ToUpper())
        {
            Y { Write-Host -ForegroundColor Green "Enabling rule..."; Enable-TransportRule $ruleName }
            N { Write-Host -ForegroundColor Yellow "Rule will remain disabled!" }
            default { Write-Host -ForegroundColor Yellow "Invalid response, try again. . ." }
        }
    }
}else{
    Write-Host -ForegroundColor Red "There appears to have been an issue creating the rule. Please manually check the rule!"
}

#ask about enabling connectors
Write-Host -ForegroundColor Yellow "Checking connectors. . ."
if (Get-InboundConnector -Identity $inConnName){
    #verify it's not already enabled
    if (!((Get-InboundConnector -Identity $inConnName).Enabled)){
        $userPrompt = ""
        while ($userPrompt.ToUpper() -ne "Y" -and $userPrompt -ne "N"){
            $userPrompt = Read-Host "Inbound connector is disabled by default, do you want to enable it now? [Y]es or [N]o"
            Switch ($userPrompt.ToUpper())
            {
                Y { Write-Host -ForegroundColor Green "Enabling connector..."; Set-InboundConnector -Identity $inConnName -Enabled $true }
                N { Write-Host -ForegroundColor Yellow "Connector will remain disabled!" }
                default { Write-Host -ForegroundColor Red "Invalid response, try again. . ." }
            }
        }
    }
}else{
    Write-Host -ForegroundColor Red "There appears to have been an issue creating the inbound connector. Please manually check it!"
}
if (Get-OutboundConnector -Identity $outConnName){
    #verify it's not already enabled
    if (!((Get-OutboundConnector -Identity $outConnName).Enabled)){
        $userPrompt = ""
        while ($userPrompt.ToUpper() -ne "Y" -and $userPrompt -ne "N"){
            $userPrompt = Read-Host "Outbound connector is disabled by default, do you want to enable it now? [Y]es or [N]o"
            Switch ($userPrompt.ToUpper())
            {
                Y { Write-Host -ForegroundColor Green "Enabling connector. . ."; $willEnableOBC = $true }
                N { Write-Host -ForegroundColor Yellow "Connector will remain disabled!" }
                default { Write-Host -ForegroundColor Red "Invalid response, try again. . ." }
            }
        }
        if ($willEnableOBC){
            $userPrompt = ""
            while ($userPrompt.ToUpper() -ne "Y" -and $userPrompt -ne "N"){
                $userPrompt = Read-Host "Do you want to validate the outbound connector first before enabling? [Y]es or [N]o"
                Switch ($userPrompt.ToUpper())
                {
                    Y {
                        Write-Host -ForegroundColor Green "Validating connector. . ."
                        #do stuff
                        while(!($validationEmail -match "^[a-zA-Z0-9]{1,}\@[a-zA-Z0-9]{1,}\.[a-zA-Z]{1,}$")){
                            $validationEmail = Read-Host "Enter a valid email address recipient for the test"
                        }
                        Write-Host -ForegroundColor Yellow "Using $validationEmail for validation. . ."
                        $validationResult = Validate-OutboundConnector -Identity $outConnName -Recipients $validationEmail
                        if ($validationResult.IsTaskSuccessful){
                            Write-Host -ForegroundColor Green "Validation was successful, connector will be enabled now. . ."
                            Set-OutboundConnector -Identity $outConnName -Enabled $true
                        }else{
                            Write-Host -ForegroundColor Red "Validation was unsuccessful. . ."
                            $userPrompt = ""
                            while ($userPrompt.ToUpper() -ne "Y" -and $userPrompt -ne "N"){
                                $userPrompt = Read-Host "Should we still enable the connector? [Y]es or [N]o"
                                Switch ($userPrompt.ToUpper())
                                {
                                    Y { Write-Host -ForegroundColor Green "Enabling connector. . ."; Set-OutboundConnector -Identity $outConnName -Enabled $true }
                                    N { Write-Host -ForegroundColor Yellow "Connector will remain disabled!" }
                                    default { Write-Host -ForegroundColor Red "Invalid response, try again. . ." }
                                }
                            }

                        }
                    }
                    N { Write-Host -ForegroundColor Yellow "Skipping validation. . ."; Set-OutboundConnector -Identity $outConnName -Enabled $true }
                    default { Write-Host -ForegroundColor Red "Invalid response, try again. . ." }
                }
            }
        }
    }
}else{
    Write-Host -ForegroundColor Red "There appears to have been an issue creating the outbound connector. Please manually check it!"
}

Write-Host -ForegroundColor Green "Script Complete"