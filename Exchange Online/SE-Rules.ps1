#SE transport rule creation
#variables
$curdate = Get-Date -Format D

<# THIS IS A TEST BLOCK FOR DYNAMICALLY RESOLVING IP ADDRESSES #>
$iplist = Resolve-DnsName -DnsOnly -NoHostsFile -type A outblock.getsitehosted.com | Select-Object IPAddress
$iplist = $iplist.IPAddress #formatting
<# THIS IS A TEST BLOCK FOR DYNAMICALLY RESOLVING IP ADDRESSES #>
<# $iplist = @(
    "69.42.49.142",
    "69.42.50.20",
    "69.42.50.104",
    "69.42.50.105",
    "69.42.50.148",
    "69.42.50.168",
    "69.42.50.210",
    "69.42.50.211",
    "69.42.50.212",
    "69.42.50.213",
    "69.42.50.242",
    "216.55.99.218",
    "69.42.49.119"
) #>
$rule1name = "Restrict delivery to SpamExperts only"
$rule1comment = "Prevent spammers from bypassing filtering and delivering direct to Office 365 endpoint. `nLast updated on $curdate"
$rule2name = "SpamExperts inbound filter bypass (ip)"
$rule2comment = "Avoid having Office 365 erroneously filter SpamExperts messages. `nLast updated on $curdate"
Write-Host -ForegroundColor Yellow "Attempting to create rules. . ."
#create lockdown rule
New-TransportRule -Name $rule1name -Comments $rule1comment -Enabled $false -Mode Enforce -FromScope NotInOrganization -DeleteMessage $true -ExceptIfSenderIpRanges $iplist -EA SilentlyContinue | Out-Null
#create filtering bypass rule
New-TransportRule -Name $rule2name -Comments $rule2comment -Enabled $false -Mode Enforce -SenderIpRanges $iplist -SetSCL -1 -EA SilentlyContinue | Out-Null
#ask if rules should be enabled or not
if ((Get-TransportRule $rule1name -EA SilentlyContinue) -And (Get-TransportRule $rule2name)){
    Write-Host -ForegroundColor Green "Rules were created successfully!"
    $userPrompt = Read-Host "Rules are by default disabled, do you want to enable them now? (Y | N)"
    Switch ($userPrompt)
    {
        Y { Write-Host -ForegroundColor Green "Enabling rules..."; Enable-TransportRule $rule1name; Enable-TransportRule $rule2name }
        N { Write-Host -ForegroundColor Yellow "Rules will remain disabled" }
        default { Write-Host -ForegroundColor Yellow "Defaulting to leave rules disabled" }
    }
    Write-Host -ForegroundColor Green "Script Complete"
}else{
    Write-Host -ForegroundColor Red "There appears to have been an issue creating one or more rules. Please manually check the existing rules!"
}