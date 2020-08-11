#check permissions on a tenant for all mailboxes/users
if ((Get-PSSession).ConfigurationName -eq "Microsoft.Exchange"){
    class SOBP {
        [string] $Mailbox
        [string] $GrantedUsers
    }
    $domains = (Get-AcceptedDomain).DomainName
    $defaultDomain = (Get-AcceptedDomain | Where-Object {$_.Default -eq $true}).DomainName
    $mailboxes = Get-Mailbox
    $recipPerms = Get-RecipientPermission
    $SOBehalfPerms = $mailboxes | Where-Object {$_.GrantSendOnBehalfTo -ne '' -and $null -ne $_.GrantSendOnBehalfTo}
    $SendOnBehalfPermissions = [System.Collections.Generic.List[SOBP]]::new()
    $SendOnBehalfPermissions.Add([SOBP]::new())
    $SendOnBehalfPermissions[0].Mailbox = 'init'
    $SendOnBehalfPermissions[0].GrantedUsers = 'init'
    $SendOnBehalfPermissions.RemoveAt(0) #object initialized, ready to add data
    $csvPath = "$PSScriptRoot\permission_audit_$($defaultDomain)_$(get-date -Format dd.MM.yyyy.HH.mm.ss).csv"
    $ph = "- - - - -"

    foreach($d in $domains){
        Write-Host -ForegroundColor Yellow "Checking domain $d for mailbox permissions:"
        $MailboxPermissions = $mailboxes | ForEach-Object{Get-MailboxPermission -Identity $_.Identity | Where-Object {$_.User -like "*$($d)"} | Select-Object Identity,User,AccessRights }
        if ($null -eq $MailboxPermissions -or [string]::IsNullOrEmpty($MailboxPermissions)){
            Write-Host "No special permissions found"
        }else{
            $MailboxPermissions | Format-Table
            [pscustomobject]@{
                Domain = $d
                Permissions = "Mailbox Permissions"
                Identity = $ph
                User = $ph
                AccessRights = $ph
                Trustee = $ph
                Mailbox = $ph
                GrantedUsers = $ph
            } | Export-Csv -Path $csvPath -NoTypeInformation -Append
            $MailboxPermissions | Export-Csv -Path $csvPath -NoTypeInformation -Append -Force
            $MailboxPermissions = $null #clear data for re-use
        }
        Write-Host -ForegroundColor Yellow "Checking domain $d for send-as permissions:"
        $SendAsPermissions = $recipPerms | Where-Object {$_.Trustee -like "*$d"} | Select-Object Identity,Trustee,AccessRights | Format-Table
        if ($null -eq $SendAsPermissions -or [string]::IsNullOrEmpty($SendAsPermissions)){
            Write-Host "No special permissions found"
        }else{
            $SendAsPermissions | Format-Table
            [pscustomobject]@{
                Domain = $d
                Permissions = "SendAs Permissions"
                Identity = $ph
                User = $ph
                AccessRights = $ph
                Trustee = $ph
                Mailbox = $ph
                GrantedUsers = $ph
            } | Export-Csv -Path $csvPath -NoTypeInformation -Append
            $SendAsPermissions | Export-Csv -Path $csvPath -NoTypeInformation -Append -Force
            $SendAsPermissions = $null #clear data for re-use
        }
        Write-Host -ForegroundColor Yellow "Checking domain $d for send-on-behalf permissions:"
        $domSOBPerms = $SOBehalfPerms | Where-Object {$_.PrimarySmtpAddress -like "*$($d)"} #filter by domain
        #check if there's more than 1 item in object now
        if ([string]::IsNullorEmpty($domSOBPerms.Length)){
            $varSize = 1
        }else{
            $varSize = $domSOBPerms.Length
        }
        for ($x=0; $x -lt $varSize; $x++){
            #loop through each mailbox
            if (!([string]::IsNullOrEmpty($domSOBPerms[$x].GrantSendOnBehalfTo))){
                $temp = $null
                ($domSOBPerms[$x] | Select-Object -ExpandProperty GrantSendOnBehalfTo) | ForEach-Object{$temp += $($_+",")}
                $newdata = [SOBP] @{ Mailbox = $domSOBPerms[$x].PrimarySmtpAddress; GrantedUsers = $temp.Trim(",")}
                $SendOnBehalfPermissions.Add($newdata)
            }
        }
        if ($null -eq $SendOnBehalfPermissions -or [string]::IsNullOrEmpty($SendOnBehalfPermissions)){
            Write-Host "No special permissions found"
        }else{
            $SendOnBehalfPermissions | Where-Object {$_.Mailbox -like "*$($d)"} | Format-Table
            [pscustomobject]@{
                Domain = $d
                Permissions = "SendOnBehalf Permissions"
                Identity = $ph
                User = $ph
                AccessRights = $ph
                Trustee = $ph
                Mailbox = $ph
                GrantedUsers = $ph
            } | Export-Csv -Path $csvPath -NoTypeInformation -Append
            $SendOnBehalfPermissions | Where-Object {$_.Mailbox -like "*$($d)"} | Export-Csv -Path $csvPath -NoTypeInformation -Append -Force
        }
    }
    Write-Host -ForegroundColor Green "Data saved to $csvPath"
    Write-Host -ForegroundColor Green "Done auditing permissions"
}else{
    Write-Host -ForegroundColor Red "Error: You need to be connected to an Exchange Online PowerShell Session first!"
}