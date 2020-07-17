#make sure the module is available to connect
if (!(Get-Command Connect-AzureAD -ErrorAction SilentlyContinue)){
    Write-Host -ForegroundColor Red "Error: You don't seem to have the AzureAD module installed. Install the module first then run this script again"
    return;
}else{
    Write-Host -ForegroundColor Green "Module appears to be installed, attempting to connect to tenant please provide the GA credentials"
    Connect-AzureAD
}

$displayName = "WilkinsITSupport"
$emailAddress = "support@wilkinsit.ca"
$redirectURL = "https://aad.portal.azure.com"

#check if user already exists
$supportUser = Get-AzureADUser -Filter "DisplayName eq '$($displayName)' and UserType eq 'Guest' and Mail eq '$($emailAddress)'"
if (!($supportUser)){
    #user doesn't exist
    Write-Host -ForegroundColor Yellow "Info: User not found, creating guest user. You'll need to accept the invite via email!"
    New-AzureADMSInvitation -InvitedUserDisplayName $displayName `
     -InvitedUserEmailAddress $emailAddress `
     -SendInvitationMessage $true `
     -InviteRedirectUrl $redirectURL | Out-Null
    
    #assign variable now that user is created
    $supportUser = Get-AzureADUser -Filter "DisplayName eq '$($displayName)' and UserType eq 'Guest' and Mail eq '$($emailAddress)'"
    if ($supportUser){Write-Host -ForegroundColor Green "Success: User created" }else{Write-Host -ForegroundColor Red "Error: user couldn't be created for some reason... exiting"; Disconnect-AzureAD; return;}
}
$appAdminRole = Get-AzureADDirectoryRole | Where-Object {$_.DisplayName -eq "Application Administrator"}
if (!($appAdminRole)){
    #if role isn't found then it needs to be enabled
    Write-Host -ForegroundColor Yellow "Info: Application Administrator role doesn't appear to be enabled, attempting to enable. . ."
    $adminRoleTemplate = Get-AzureADDirectoryRoleTemplate | Where-Object {$_.DisplayName -eq "Application Administrator"}
    Enable-AzureADDirectoryRole -RoleTemplateId $adminRoleTemplate.ObjectId
    #reassign variable with enabled role
    $appAdminRole = Get-AzureADDirectoryRole | Where-Object {$_.DisplayName -eq "Application Administrator"}
    if (!($appAdminRole)){Write-Host -ForegroundColor Red "Error: We don't seem to have been able to enable the role! Exiting..."; return;}
}

#add as app administrator
Write-Host -ForegroundColor Yellow "Info: Assigning Application Administrator role to $displayName . . ."
Add-AzureADDirectoryRoleMember -ObjectId $appAdminRole.ObjectId -RefObjectId $supportUser.ObjectId
$roleMembers = Get-AzureADDirectoryRoleMember -ObjectId $appAdminRole.ObjectId
if (($roleMembers | Where-Object {$_.Mail -eq $emailAddress})){
    Write-Host -ForegroundColor Green "Success: Role assigned"
}else{
    Write-Host -ForegroundColor Red "Error: Role wasn't able to be assigned for some reason... exiting"
    Disconnect-AzureAD
    return;
}

Write-Host -ForegroundColor Yellow "Info: Disconnecting from AzureAD tenant. . ."
Disconnect-AzureAD | Out-Null
Write-Host -ForegroundColor Green "Script Complete!"