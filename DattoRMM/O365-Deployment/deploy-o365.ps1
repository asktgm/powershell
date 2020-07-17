# used to deploy Office 365 apps via the deployment tool for various configurations

$setupFile = ".\365setup.exe"
$configFile = ".\configuration.xml"
$xmlConfigFile = [xml](Get-Content $configFile)
$psArgs1 = @('/download',"$configFile")
$psArgs2 = @('/configure',"$configFile")

$appsToInstall = @()
#build variable for apps to install
if ($env:InstallAccess -eq 'True'){ $appsToInstall += "Access" }
if ($env:InstallExcel -eq 'True'){ $appsToInstall += "Excel" }
#[bool]$env:InstallGroove # never install
if ($env:InstallSkype -eq 'True'){ $appsToInstall += "Lync" }
if ($env:InstallOneDrive -eq 'True'){ $appsToInstall += "OneDrive" }
if ($env:InstallOneNote -eq 'True'){ $appsToInstall += "OneNote" }
if ($env:InstallOutlook -eq 'True'){ $appsToInstall += "Outlook" }
if ($env:InstallPowerPoint -eq 'True'){ $appsToInstall += "PowerPoint" }
if ($env:InstallPublisher -eq 'True'){ $appsToInstall += "Publisher" }
if($env:InstallWord -eq 'True'){ $appsToInstall += "Word" }
$excludeAppList = @('Access','Excel','Groove','Lync','OneDrive','OneNote','Outlook','PowerPoint','Publisher','Word')
$officeArch = $env:ArchitectureBits #32 or 64
$officeVariant = $env:Variant #O365BusinessRetail or O365ProPlusRetail
$excludeAppList = $excludeAppList | Where-Object { $appsToInstall -contains $_ } #filter out items we'll be installing
#now rewrite the XML file
#remove exclusions for stuff being installed
$childItems = $xmlConfigFile.SelectNodes('//ExcludeApp')
foreach($item in $childItems){
    foreach($exclusion in $excludeAppList){
        if ($item.ID -eq $exclusion){
            [void]$item.ParentNode.RemoveChild($item)
        }
    }
}
#set the architecture value
$xmlConfigFile.Configuration.Add.SetAttribute("OfficeClientEdition",$officeArch)
#set the office variant
$xmlConfigFile.Configuration.Add.Product.SetAttribute("ID",$officeVariant)
#write the file changes
$xmlConfigFile.Save($configFile)

#download
Start-Process -FilePath $setupFile -ArgumentList $psArgs1 -Wait
#install
Start-Process -FilePath $setupFile -ArgumentList $psArgs2 -Wait

#output for dRMM
Write-Host "-Script Result-"
Write-Host -NoNewline "Apps to install: "
foreach($i in $appsToInstall){ Write-Host -NoNewline "$i " }
Write-Host ""
Write-Host "Architecture: $officeArch"
Write-Host "Office variant: $officeVariant"