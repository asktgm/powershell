#script to add a new organization relationship in exchange online powershell

param (
    [switch]$force #if called will ignore the pattern match check
)

$orgToAdd = Read-Host "Enter the organization domain you're adding"
if (!($orgToAdd -match "^[a-zA-Z0-9]{1}[a-zA-Z0-9\-]{0,62}\.([a-zA-Z]{1,3}\.[a-zA-Z]{1,2}|[a-zA-Z]{1,10})$" -and !($force))){
    #wrong format for domain (probably) and we're not forcing
    Write-Host -ForegroundColor Red "domain appears to be in invalid format! If you're sure it's correct call this script with the -force parameter"
    return;
}else{
    if ($force){Write-Host "Info: Ignoring domain validation check"}
    if ((Get-PSSession).ComputerName -eq "outlook.office365.com"){
        $curTenant = (Get-OrganizationConfig).DisplayName
        $extTenant = Get-FederationInformation -DomainName $orgToAdd
        if ([string]::IsNullOrEmpty($extTenant)){
            Write-Host -ForegroundColor Red "Error: Unable to retreive information for $orgToAdd, exiting. . ."
            return;
        }
        Write-Host -ForegroundColor Yellow "You're currently connected to the tenant for $curTenant - enabling relationship for $orgToAdd. . ."
        $extTenant | New-OrganizationRelationship -Name "$orgToAdd" -FreeBusyAccessEnabled $false -FreeBusyAccessLevel None -MailTipsAccessLevel All -MailTipsAccessEnabled $true
        Start-Sleep -Seconds 3
        if ((Get-OrganizationRelationship -Identity $orgToAdd).IsValid){
            Write-Host -ForegroundColor Green "Success: Relationship has been added"
        }else{
            Write-Host -ForegroundColor Red "Error: Unable to confirm relationship was added. This can happen due to exchange server delays, check manually to confirm."
        }
        Write-Host "Script complete"
    }else{
        Write-Host -ForegroundColor Red "Error: You need to be connected to an exchange online powershell session first!"
        return;
    }   
}