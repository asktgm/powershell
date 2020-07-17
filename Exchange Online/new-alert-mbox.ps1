#exchange online powershell script for creating new ticket alert mailboxes
#last update: May 25 2020

Clear-Host

#Custom function for creating mailbox
function New-AlertMailbox{
    param(
        [Parameter(Mandatory=$true)][string]$ForwardAddress,
        [Parameter(Mandatory=$true)][string]$DisplayName,
        [Parameter(Mandatory=$true)][string]$MboxAddress
    )

    if (Get-Mailbox -Identity $MboxAddress -ErrorAction SilentlyContinue){
        Write-Host -ForegroundColor Red "Error! This mailbox already exists! Exiting..."
        return;
    }else{
        Write-Host "Creating mailbox. . ."
        New-Mailbox -Shared -Name $DisplayName -DisplayName $DisplayName -Alias $MboxAddress.Substring(0,$MboxAddress.IndexOf("@")) -PrimarySmtpAddress $MboxAddress | Out-Null
        ping.exe -n 5 127.1 | Out-Null #delay gathering info about the mailbox, try to avoid issues with provisioning
        $newMbox = Get-Mailbox -Identity $MboxAddress
        Set-Mailbox -Identity $newMbox.Identity -HiddenFromAddressListsEnabled $true
        if ($newMbox){
            Write-Host -ForegroundColor Green "Done!"
            Write-Host "Setting regional configuration. . ."
            ping.exe -n 10 127.1 | Out-Null #delay 10 seconds to allow provisioning
            Set-MailboxRegionalConfiguration -Identity $newMbox.Alias -Language "en-CA" -DateFormat "yyyy-MM-dd" -TimeFormat "h:mm tt"
            Write-Host -ForegroundColor Green "Done!"
            Write-Host "Creating inbox rule for alerts. . ."
            New-InboxRule -Mailbox $newMbox.Alias -ForwardTo $defFwdAddr -Name "Forward to support desk" -StopProcessingRules $true | Out-Null
            ping.exe -n 3 127.1 | Out-Null #delay to allow rule propagation
            $hasRule = Get-InboxRule -Mailbox $newMbox.Alias
            if (!$hasRule){
                Write-Host -ForegroundColor Yellow "There appears to have been an error creating the forwarding rule. This could be a delay from Exchange Online, check it manually to confirm!"
            }
            Write-Host -ForegroundColor Green "Done!"
        }else{
            Write-Host -ForegroundColor Red "Error: Couldn't locate the newly created mailbox for some reason. Exiting. . ."
            return;
        }
    }
}

#Connect to exchange online first
#check if module installed first
$EXOMInstalled = Get-InstalledModule -Name ExchangeOnlineManagement -ErrorAction SilentlyContinue
if (!$EXOMInstalled){
    Write-Host -ForegroundColor Red -BackgroundColor Black "ERROR: The module ExchangeOnlineManagement is required to run this script! Install it first then try running this again."
    Write-Host -ForegroundColor Red -BackgroundColor Black "exiting now. . ."
    return;
}else{
    #check if already connected to exchange online
    $EXOMSession = Get-PSSession | Where-Object {$_.Name -like "ExchangeOnlineInternalSession*"} 
    if ($EXOMSession){
        #existing session found, verify it's the WITS tenant
        Write-Host -ForegroundColor Yellow "Found existing Exchange Online PowerShell session, checking the organization. . ."
        $sessionOrg = Get-OrganizationalUnit | Select-Object Name | Where-Object {$_.Name -eq 'wilkinsitca.onmicrosoft.com'}
        if (!($sessionOrg.Name -eq "wilkinsitca.onmicrosoft.com")){
            Write-Host -ForegroundColor Yellow "Existing Exchange Online PowerShell session found but organization isn't correct"
            Write-Host -ForegroundColor Yellow "Connecting to Exchange Online PowerShell, use your WITS Office 365 credentials to complete the login!"
            Connect-ExchangeOnline
            $EXOMSession = Get-PSSession | Where-Object {$_.Name -like "ExchangeOnlineInternalSession*"}
            if (!$EXOMSession){
                Write-Host -ForegroundColor Red -BackgroundColor Black "ERROR: There was an error connecting to exchange online (wrong credentials or no permission?). Exiting. . ."
                return;
            }
        }else{
            Write-Host -ForegroundColor Green "Appears to be the correct organization! Skipping creation of Exchange Online PowerShell session!"
        }
    }else{
        #no existing session found
        Write-Host -ForegroundColor Yellow "Connecting to Exchange Online PowerShell, use your WITS Office 365 credentials to complete the login!"
        Connect-ExchangeOnline
        $EXOMSession = Get-PSSession | Where-Object {$_.Name -like "ExchangeOnlineInternalSession*"}
        if (!$EXOMSession){
            Write-Host -ForegroundColor Red -BackgroundColor Black "ERROR: There was an error connecting to exchange online (wrong credentials or no permission?). Exiting. . ."
            return;
        }
    }
}

$defDomain = "@wilkinsit.ca"
$defFwdAddr = "valerts@wilkinsit.com"

$newMailboxName = Read-Host -Prompt 'Enter the client name for whom this mailbox is used (short form is okay)'
$newMailboxAddr = Read-Host -Prompt 'Enter the client number'

$newMailboxName = "WITS $($newMailboxName)" #prepend WITS for display name
$newMailboxAddr = "wilkinsit_$($newMailboxAddr)" #prepend template name to client number

Write-Host "You're about to create a new alerts mailbox with the following information:" -BackgroundColor Black -ForegroundColor White
Write-Host "Display Name - $($newMailboxName)"
Write-Host "Email Address - $($newMailboxAddr)$($defDomain)"
$userConfirm = Read-Host 'Confirm this is correct ([Y]es] / [N]o)'

if (($userConfirm.ToLower().Contains('y'))){
    #do the stuff!
    New-AlertMailbox -ForwardAddress $defFwdAddr -DisplayName $newMailboxName -MboxAddress "$($newMailboxAddr)$($defDomain)"
    
    #create another?
    $userConfirm = Read-Host -Prompt 'Do you want to create another alert mailbox ([Y]es] / [N]o)'
    while ($userConfirm.ToLower().Contains('y')) {
        $newMailboxName = Read-Host -Prompt 'Enter the client name for whom this mailbox is used (short form is okay)'
        $newMailboxAddr = Read-Host -Prompt 'Enter the client number'
        $newMailboxName = "WITS $($newMailboxName)" #prepend WITS for display name
        $newMailboxAddr = "wilkinsit_$($newMailboxAddr)" #prepend template name to client number
        New-AlertMailbox -ForwardAddress $defFwdAddr -DisplayName $newMailboxName -MboxAddress "$($newMailboxAddr)$($defDomain)"
        $userConfirm = Read-Host -Prompt 'Do you want to create another alert mailbox ([Y]es] / [N]o)'
    }
    #disconnect from exchange online?
    $userConfirm = Read-Host -Prompt 'Do you want to disconnect from Exchange Online now ([Y]es] / [N]o)'
    if ($userConfirm.ToLower().Contains('y')){
        Write-Host -ForegroundColor Yellow "Disconnecting from Exchange Online PowerShell session. . ."
        $EXOMSession | Remove-PSSession
        if (!$(Get-PSSession | Where-Object {$_.Name -like "ExchangeOnlineInternalSession*"})){
            Write-Host -ForegroundColor Green "Disconnected successfully!`nScript Finished"
        }else{
            Write-Host -ForegroundColor Red "There appears to have been an error disconnecting, try entering the following command to manually disconnect:"
            Write-Host -ForegroundColor Yellow "`nGet-PSSession | Remove-PSSession`n"
            Write-Host -ForegroundColor Red "If you do not disconnect the session will eventually time out, but this could cause short term issues otherwise"
            return;
        }
    }else{
        Write-Host -ForegroundColor Yellow "Exchange Online PowerShell session left active. Remember to disconnect when you're done!"
    }
    
}elseif (($userConfirm.ToLower().Contains('n'))) {
    #exit
    Write-Host -ForegroundColor Red "Exiting script, run it again if you mistyped information."
    exit;
}else{
    Write-Host -ForegroundColor Red "Invalid entry, exiting!"
    return;
}