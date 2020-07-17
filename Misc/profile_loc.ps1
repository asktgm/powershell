#This is the script used to move user profile folders into the OneDrive folder quickly
#Can also be used to modify an existing OneDrive linking if this was previously set up
#Last Updated: June 5th, 2020 by Andrew Newell
#Current known issues? None


Clear-Host
Write-Host -ForegroundColor Yellow "Info: Refreshing environment variables. . ."
foreach($level in "Machine","User"){
    [Environment]::GetEnvironmentVariables($level) | Out-Null
    Write-Host -ForegroundColor Yellow "Info: Refreshed variables for $level"
}

$setupType = 0
While ($setupType -ne 1 -and $setupType -ne 2){
    Switch (Read-Host "What kind of setup is being performed?`n`t[ 1 ] - New OneDrive profile linking setup`n`t[ 2 ] - Modifying existing OneDrive profile linking`n`nSelection")
    { 
        1 {Write-host "New profile linking setup selected" -ForegroundColor Green; $setupType=1} 
        2 {Write-host "Existing profile linking modification selected" -ForegroundColor Green; $setupType=2}
        Default {Write-Host -ForegroundColor Red "Incorrect selection, try again" }
    }
}

if ($setupType -eq 1){
    #check if OneDrive environment variable is valid
    if(![string]::IsNullOrEmpty($env:OneDrive)) {
        $ODPath = $env:OneDrive
        #verify with user the detected path is correct
        Write-Host "Detected OneDrive path: $($ODPath)"
        Switch (Read-Host "Confirm the above path is correct ( Y or N ) ")
        { 
            Y {Write-host "Confirmed" -ForegroundColor Green; $userConfirm=$true} 
            N {$userConfirm=$false} 
            Default {$userConfirm=$false}
        }
        if (!$userConfirm){
            $ODPath = Read-Host -Prompt "Please provide the correct OneDrive path (copy/paste from it windows explorer)"
        }
    }else{
        $ODPath = Read-Host -Prompt "Couldn't locate OneDrive path please provide it (copy/paste it from windows explorer)"
    }

    $userPath = $env:USERPROFILE
    $userConfirm=$false #reset from last decision
    Write-Host "Detected UserProfile path: $($userPath)"
        Switch (Read-Host "Confirm the above path is correct ( Y or N ) ")
        { 
            Y {Write-host "Confirmed" -ForegroundColor Green; $userConfirm=$true} 
            N {$userConfirm=$false} 
            Default {$userConfirm=$false}
        }
        if (!$userConfirm){
            $userPath = Read-Host -Prompt "Please provide the correct UserProfile path (copy/paste it from windows explorer)"
        }

    #offer to change path to sub-user-folder (for multi-PC use)
    $ODPathSub = "user"
    $userConfirm=$false #reset from last decision
    Write-Host "By default we'll use $($ODPath)\$($ODPathSub) to place profile folders inside"
        Switch (Read-Host "Confirm the above path is okay to use ( Y or N ) ")
        { 
            Y {Write-host "Confirmed" -ForegroundColor Green; $userConfirm=$true} 
            N {$userConfirm=$false} 
            Default {$userConfirm=$false}
        }
        while (!$userConfirm){
            $ODPathSub = Read-Host -Prompt "Please provide the subfolder path to use inside $($ODPath)"
            $ODPathSub = $ODPathSub.Trim("\") #trim leading/trailing slashes
            Write-Host "Full path will be $($ODPath)\$($ODPathSub)"
            Switch (Read-Host "Please confirm path looks correct ( Y or N ) ")
            { 
                Y {Write-host "Confirmed!" -ForegroundColor Green; $userConfirm=$true} 
                N {$userConfirm=$false} 
                Default {$userConfirm=$false}
            }

        }

    if (!(Test-Path -Path $ODPath)){Write-Host "The OneDrive path is invalid.. press any key to exit..."; Read-Host; exit}
    if (!(Test-Path -Path $userPath)){Write-Host "The UserProfile path is invalid.. press any key to exit..."; Read-Host; exit}
    #build variables
    #new location
    $newPath = new-object psobject
    $newPath | add-member noteproperty contacts "$($ODPath)\$($ODPathSub)\Contacts"
    $newPath | add-member noteproperty desktop "$($ODPath)\$($ODPathSub)\Desktop"
    $newPath | add-member noteproperty documents "$($ODPath)\$($ODPathSub)\Documents"
    $newPath | add-member noteproperty downloads "$($ODPath)\$($ODPathSub)\Downloads"
    $newPath | add-member noteproperty favorites "$($ODPath)\$($ODPathSub)\Favorites"
    $newPath | add-member noteproperty links "$($ODPath)\$($ODPathSub)\Links"
    $newPath | add-member noteproperty music "$($ODPath)\$($ODPathSub)\Music"
    $newPath | add-member noteproperty pictures "$($ODPath)\$($ODPathSub)\Pictures"
    $newPath | add-member noteproperty videos "$($ODPath)\$($ODPathSub)\Videos"
    #old location
    $oldPath = New-Object psobject
    $oldPath | Add-Member noteproperty contacts "$($userPath)\Contacts"
    $oldPath | Add-Member noteproperty desktop "$($userPath)\Desktop"
    $oldPath | Add-Member noteproperty documents "$($userPath)\Documents"
    $oldPath | Add-Member noteproperty downloads "$($userPath)\Downloads"
    $oldPath | Add-Member noteproperty favorites "$($userPath)\Favorites"
    $oldPath | Add-Member noteproperty links "$($userPath)\Links"
    $oldPath | Add-Member noteproperty music "$($userPath)\Music"
    $oldPath | Add-Member noteproperty pictures "$($userPath)\Pictures"
    $oldPath | Add-Member noteproperty videos "$($userPath)\Videos"
    #registry keys to edit
    $key1 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    $key2 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"

    #create profile subfolder if not existing
    Write-Host -ForegroundColor Yellow "Creating new folders..."
    if (!(Test-Path -Path "$($ODPath)\$($ODPathSub)")){ New-Item -ItemType directory -Path "$($ODPath)\$($ODPathSub)" | Out-Null }
    #create profile folders in onedrive if they don't exist
    if (!(Test-Path -Path $newPath.contacts)){ New-Item -ItemType directory -Path $newPath.contacts | Out-Null }
    if (!(Test-Path -Path $newPath.desktop)){ New-Item -ItemType directory -Path $newPath.desktop | Out-Null }
    if (!(Test-Path -Path $newPath.documents)){ New-Item -ItemType directory -Path $newPath.documents | Out-Null }
    if (!(Test-Path -Path $newPath.downloads)){ New-Item -ItemType directory -Path $newPath.downloads | Out-Null }
    if (!(Test-Path -Path $newPath.favorites)){ New-Item -ItemType directory -Path $newPath.favorites | Out-Null }
    if (!(Test-Path -Path $newPath.links)){ New-Item -ItemType directory -Path $newPath.links | Out-Null }
    if (!(Test-Path -Path $newPath.music)){ New-Item -ItemType directory -Path $newPath.music | Out-Null }
    if (!(Test-Path -Path $newPath.pictures)){ New-Item -ItemType directory -Path $newPath.pictures | Out-Null }
    if (!(Test-Path -Path $newPath.videos)){ New-Item -ItemType directory -Path $newPath.videos | Out-Null }

    #move files 
    #kill explorer and others to be sure first
    Write-Host -ForegroundColor Yellow "Killing processes..."
    $killedProcesses = @() #used to restart processes afterwards
    if (Get-Process -Name "explorer" -ErrorAction SilentlyContinue){ taskkill.exe /f /im explorer.exe > $null 2>&1 <# taskkill prevents auto-restarting it #>; $killedProcesses += "explorer.exe" }
    if (Get-Process -Name "outlook" -ErrorAction SilentlyContinue){ Stop-Process -Name "outlook" -Force -Confirm:$false; $killedProcesses += "outlook.exe" }
    if (Get-Process -Name "excel" -ErrorAction SilentlyContinue){ Stop-Process -Name "excel" -Force -Confirm:$false; $killedProcesses += "excel.exe" }
    if (Get-Process -Name "winword" -ErrorAction SilentlyContinue){ Stop-Process -Name "winword" -Force -Confirm:$false; $killedProcesses += "winword.exe" }
    if (Get-Process -Name "POWERPNT" -ErrorAction SilentlyContinue){ Stop-Process -Name "POWERPNT" -Force -Confirm:$false; $killedProcesses += "POWERPNT.exe" }
    if (Get-Process -Name "MSACCESS" -ErrorAction SilentlyContinue){ Stop-Process -Name "MSACCESS" -Force -Confirm:$false; $killedProcesses += "MSACCESS.exe" }
    if (Get-Process -Name "onedrive" -ErrorAction SilentlyContinue){ Stop-Process -Name "onedrive" -Force -Confirm:$false; $killedProcesses += "$env:LOCALAPPDATA\Microsoft\OneDrive\onedrive.exe" }
    Write-Host -ForegroundColor Yellow "Done killing processes."

    #move the files
    Write-Host -ForegroundColor Yellow "Moving files around..."
    Move-Item -Path "$($oldPath.contacts)\*" -Destination "$($newPath.contacts)\" -ErrorAction SilentlyContinue
    Move-Item -Path "$($oldPath.desktop)\*" -Destination "$($newPath.desktop)\" -ErrorAction SilentlyContinue
    Move-Item -Path "$($oldPath.documents)\*" -Destination "$($newPath.documents)\" -ErrorAction SilentlyContinue
    Move-Item -Path "$($oldPath.downloads)\*" -Destination "$($newPath.downloads)\" -ErrorAction SilentlyContinue
    Move-Item -Path "$($oldPath.favorites)\*" -Destination "$($newPath.favorites)\" -ErrorAction SilentlyContinue
    Move-Item -Path "$($oldPath.links)\*" -Destination "$($newPath.links)\" -ErrorAction SilentlyContinue
    Move-Item -Path "$($oldPath.music)\*" -Destination "$($newPath.music)\" -ErrorAction SilentlyContinue
    Move-Item -Path "$($oldPath.pictures)\*" -Destination "$($newPath.pictures)\" -ErrorAction SilentlyContinue
    Move-Item -Path "$($oldPath.videos)\*" -Destination "$($newPath.videos)\" -ErrorAction SilentlyContinue
    Write-Host -ForegroundColor Yellow "Done moving files."

    #change keys now
    Write-Host -ForegroundColor Yellow "Updating registry keys..."
    #User Shell Folders
    set-ItemProperty -path $key1 -name '{56784854-C6CB-462B-8169-88E350ACB882}' $newPath.contacts
    set-ItemProperty -path $key1 -name Desktop $newPath.desktop
    set-ItemProperty -path $key1 -name '{754AC886-DF64-4CBA-86B5-F7FBF4FBCEF5}' $newPath.desktop
    set-ItemProperty -path $key1 -name '{F42EE2D3-909F-4907-8871-4C22FC0BF756}' $newPath.documents
    set-ItemProperty -path $key1 -name Personal $newPath.documents
    set-ItemProperty -path $key1 -name '{374DE290-123F-4565-9164-39C4925E467B}' $newPath.downloads
    set-ItemProperty -path $key1 -name '{7D83EE9B-2244-4E70-B1F5-5393042AF1E4}' $newPath.downloads
    set-ItemProperty -path $key1 -name Favorites $newPath.favorites
    set-ItemProperty -path $key1 -name 'My Music' $newPath.music
    set-ItemProperty -path $key1 -name '{A0C69A99-21C8-4671-8703-7934162FCF1D}' $newPath.music
    set-ItemProperty -path $key1 -name '{0DDD015D-B06C-45D5-8C4C-F59713854639}' $newPath.pictures
    set-ItemProperty -path $key1 -name 'My Pictures' $newPath.pictures
    set-ItemProperty -path $key1 -name '{35286A68-3C57-41A1-BBB1-0EAE73D76C95}' $newPath.videos
    set-ItemProperty -path $key1 -name 'My Video' $newPath.videos
    #Shell Folders
    set-ItemProperty -path $key2 -name '{56784854-C6CB-462B-8169-88E350ACB882}' $newPath.contacts
    set-ItemProperty -path $key2 -name Desktop $newPath.desktop
    set-ItemProperty -path $key2 -name Personal $newPath.documents
    set-ItemProperty -path $key2 -name '{374DE290-123F-4565-9164-39C4925E467B}' $newPath.downloads
    set-ItemProperty -path $key2 -name Favorites $newPath.favorites
    set-ItemProperty -path $key2 -name '{BFB9D5E0-C6A9-404C-B2B2-AE6DB6AF4968}' $newPath.links
    set-ItemProperty -path $key2 -name 'My Music' $newPath.music
    set-ItemProperty -path $key2 -name 'My Pictures' $newPath.pictures
    set-ItemProperty -path $key2 -name 'My Video' $newPath.videos

    #restart killed processes now
    Write-Host -ForegroundColor Yellow "Restarting killed processes..."
    foreach($process in $killedProcesses){
        Start-Process $process
    }
    Write-Host -ForegroundColor Yellow "Done restarting processes."
    Write-Host -ForegroundColor Black -BackgroundColor Green @"
    `n
    ALL DONE
    You should restart the computer as soon as possible!`n
"@
}elseif($setupType -eq 2){
    # use this to move folders from a OneDrive location with a new name

    #VARS
    $OD_userSubFolder = "user"
    $OD_regVerify = $true #for verifying user folder exists
    $userConfirm = $false
    $userChoice = 0
    #User Input VARs
    $OD_oldPath = Read-Host -Prompt "Please provide the OneDrive path we're moving FROM"
    $OD_newPath = Read-Host -Prompt "Please provide the OneDrive path we're moving TO"

    Write-Host "Is the user profile folder `"$($OD_userSubFolder)`" being used and correct?"
    Switch (Read-Host "Make a selection `n[ Y ] - Correct `n[ N ] - Not being used `n[ X ] - Incorrect sub-folder name `nAnswer")
        { 
            Y {Write-host "Correct" -ForegroundColor Green; $userChoice=1} 
            N {Write-Host "Not being used" -ForegroundColor Green; $userChoice=0}
            X {Write-Host "Wrong sub-folder name" -ForegroundColor Yellow; $userChoice=2} 
            Default {Write-Host "Defaulting to 'not used'" -ForegroundColor Yellow; $userChoice=0}
        }
    if ($userChoice -eq 2) #update the folder name
        {
            $OD_userSubFolder = Read-Host -Prompt "Provide the correct folder name"
            $OD_regVerify = $true
        }
    ElseIf ($userChoice -eq 1)
        {
            $OD_regVerify = $true
        }
    ElseIf ($userChoice -eq 0)
        {
            $OD_regVerify = $false
        }

    #verify that the folder exists, otherwise we could screw it up real bad
    if ((!(Test-Path -Path "$($OD_oldPath)\$($OD_userSubFolder)")) -And ($OD_regVerify))
        {
            Write-Host "Couldn't verify the user folder exists!!! We're stopping now. . ." -ForegroundColor Red
            Read-Host
            exit
        }

    #move files 
    #kill explorer and others to be sure first
    Write-Host -ForegroundColor Yellow "Killing related processes..."
    taskkill.exe /f /im explorer.exe > $null 2>&1
    taskkill.exe /f /im outlook.exe > $null 2>&1
    taskkill.exe /f /im excel.exe > $null 2>&1
    taskkill.exe /f /im winword.exe > $null 2>&1
    #move the files
    Write-Host -ForegroundColor Yellow "Moving files around..."
    Move-Item -Path "$($OD_oldPath)\*" -Destination "$($OD_newPath)\"

    #if we're moving user profile folders update the registry
    if ($userChoice -ne 0)
        {
            #registry keys to edit
            $key1 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
            $key2 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"

            #build registry path variables
            #new location
            $newPath = new-object psobject
            $newPath | add-member noteproperty contacts "$($OD_newPath)\$($OD_userSubFolder)\Contacts"
            $newPath | add-member noteproperty desktop "$($OD_newPath)\$($OD_userSubFolder)\Desktop"
            $newPath | add-member noteproperty documents "$($OD_newPath)\$($OD_userSubFolder)\Documents"
            $newPath | add-member noteproperty downloads "$($OD_newPath)\$($OD_userSubFolder)\Downloads"
            $newPath | add-member noteproperty favorites "$($OD_newPath)\$($OD_userSubFolder)\Favorites"
            $newPath | add-member noteproperty links "$($OD_newPath)\$($OD_userSubFolder)\Links"
            $newPath | add-member noteproperty music "$($OD_newPath)\$($OD_userSubFolder)\Music"
            $newPath | add-member noteproperty pictures "$($OD_newPath)\$($OD_userSubFolder)\Pictures"
            $newPath | add-member noteproperty videos "$($OD_newPath)\$($OD_userSubFolder)\Videos"

            Write-Host -ForegroundColor Yellow "Updating registry keys..."
            #User Shell Folders
            set-ItemProperty -path $key1 -name '{56784854-C6CB-462B-8169-88E350ACB882}' $newPath.contacts
            set-ItemProperty -path $key1 -name Desktop $newPath.desktop
            set-ItemProperty -path $key1 -name '{754AC886-DF64-4CBA-86B5-F7FBF4FBCEF5}' $newPath.desktop
            set-ItemProperty -path $key1 -name '{F42EE2D3-909F-4907-8871-4C22FC0BF756}' $newPath.documents
            set-ItemProperty -path $key1 -name Personal $newPath.documents
            set-ItemProperty -path $key1 -name '{374DE290-123F-4565-9164-39C4925E467B}' $newPath.downloads
            set-ItemProperty -path $key1 -name '{7D83EE9B-2244-4E70-B1F5-5393042AF1E4}' $newPath.downloads
            set-ItemProperty -path $key1 -name Favorites $newPath.favorites
            set-ItemProperty -path $key1 -name 'My Music' $newPath.music
            set-ItemProperty -path $key1 -name '{A0C69A99-21C8-4671-8703-7934162FCF1D}' $newPath.music
            set-ItemProperty -path $key1 -name '{0DDD015D-B06C-45D5-8C4C-F59713854639}' $newPath.pictures
            set-ItemProperty -path $key1 -name 'My Pictures' $newPath.pictures
            set-ItemProperty -path $key1 -name '{35286A68-3C57-41A1-BBB1-0EAE73D76C95}' $newPath.videos
            set-ItemProperty -path $key1 -name 'My Video' $newPath.videos
            #Shell Folders
            set-ItemProperty -path $key2 -name '{56784854-C6CB-462B-8169-88E350ACB882}' $newPath.contacts
            set-ItemProperty -path $key2 -name Desktop $newPath.desktop
            set-ItemProperty -path $key2 -name Personal $newPath.documents
            set-ItemProperty -path $key2 -name '{374DE290-123F-4565-9164-39C4925E467B}' $newPath.downloads
            set-ItemProperty -path $key2 -name Favorites $newPath.favorites
            set-ItemProperty -path $key2 -name '{BFB9D5E0-C6A9-404C-B2B2-AE6DB6AF4968}' $newPath.links
            set-ItemProperty -path $key2 -name 'My Music' $newPath.music
            set-ItemProperty -path $key2 -name 'My Pictures' $newPath.pictures
            set-ItemProperty -path $key2 -name 'My Video' $newPath.videos
        }

    #restart explorer now
    Start-Process explorer.exe
    Write-Host -ForegroundColor Green "All done. . . restart the computer!"
}else{
    Write-Host -ForegroundColor Red "Error: something went wrong. . ."
}
