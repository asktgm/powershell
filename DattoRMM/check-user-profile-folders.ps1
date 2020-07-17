#determine sizes of user profile folders

#store variables in child objects
$profileFolder = new-object psobject
$profileFolder | add-member noteproperty contacts "$($env:USERPROFILE)\Contacts"
$profileFolder | add-member noteproperty desktop "$($env:USERPROFILE)\Desktop"
$profileFolder | add-member noteproperty documents "$($env:USERPROFILE)\Documents"
$profileFolder | add-member noteproperty downloads "$($env:USERPROFILE)\Downloads"
$profileFolder | add-member noteproperty favorites "$($env:USERPROFILE)\Favorites"
$profileFolder | add-member noteproperty links "$($env:USERPROFILE)\Links"
$profileFolder | add-member noteproperty music "$($env:USERPROFILE)\Music"
$profileFolder | add-member noteproperty pictures "$($env:USERPROFILE)\Pictures"
$profileFolder | add-member noteproperty videos "$($env:USERPROFILE)\Videos"

$folder = New-Object psobject
$folder | Add-Member NoteProperty contacts ""
$folder | Add-Member NoteProperty desktop ""
$folder | Add-Member NoteProperty documents ""
$folder | Add-Member NoteProperty downloads ""
$folder | Add-Member NoteProperty favorites ""
$folder | Add-Member NoteProperty links ""
$folder | Add-Member NoteProperty music ""
$folder | Add-Member NoteProperty pictures ""
$folder | Add-Member NoteProperty videos ""


$profileFolder.PSObject.Properties | foreach-object {
    $dirName = $_.Name
    $dirPath = $_.Value   #this should be the directory path
    
    if (Test-Path -Path $dirPath){
        #the path exists and we can check it
        $dirItem = Get-Item -Path $dirPath
        $folder.$($dirname) = $dirItem | Get-ChildItem | Measure-Object -Sum Length | Select-Object `
            @{Name=”Path”; Expression={$directory.FullName}},
            @{Name=”Files”; Expression={$_.Count}},
            @{Name=”Size”; Expression={$_.Sum}}
     }

    #null the noteproperty if it didn't get filled in
     if ([string]::IsNullOrEmpty($folder.$($dirName))){
         $folder.$($dirName) = $null
     }
}

ForEach-Object 
