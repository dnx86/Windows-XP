# Setup and configure WSUS for Windows XP and XP Embedded. 32-bit only.
# Tested on Windows Server 2022. The script is assumed to run after a clean installation.
# 1,747 updates using 4,955.52 MB of space.
# For Windows Server 2025, see "Hardening changes for Windows Server Update Services in Windows Server 2025". Link below.
# https://support.microsoft.com/en-us/topic/hardening-changes-for-windows-server-update-services-in-windows-server-2025-170eba05-0532-4793-a9c7-0857a62df52f
#
# This script is based on the scripts in the links below:
# https://gist.github.com/devynspencer/e6bfc5efc7274689c509c7300c8405c8
# https://www.reddit.com/r/sysadmin/comments/cmanmd/powershell_script_for_configuring_a_wsus_server

#Requires -RunAsAdministrator
#Requires -Version 5.1

# Checks if the WSUS server role is installed and installs it if it's not.
if ((Get-WindowsFeature -Name UpdateServices).Installed -eq $false) {
    Write-Host "Installing WSUS..."
    Install-WindowsFeature -Name UpdateServices -IncludeManagementTools -Restart
}

$pathContentDirectory = "$env:SystemDrive\WSUS-Updates"
if ( (Test-Path -Path $pathContentDirectory) -eq $false ) {
    Write-Host "Creating the content directory..."
    New-Item -Path "$pathContentDirectory" -ItemType Directory | Out-Null
}

Write-Host "Running WsusUtil for postinstall..."
Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\Update Services\Tools\WsusUtil.exe" -ArgumentList "postinstall CONTENT_DIR=$pathContentDirectory"

# Get WSUS server and configuration.
$wsus = Get-WSUSServer
$wsusConfig = $wsus.GetConfiguration()

# Set to download updates from Microsoft Updates.
Set-WsusServerSynchronization -SyncFromMU

# Set Update Languages to English and save configuration settings.
$wsusConfig.AllUpdateLanguagesEnabled = $false
$wsusConfig.SetEnabledUpdateLanguages("en")
$wsusConfig.Save()

# Get WSUS subscription and perform initial synchronization to get latest categories.
Write-Host "Synchronizing to get the latest categories!"
$subscription = $wsus.GetSubscription()
$subscription.StartSynchronizationForCategoryOnly()
$StartDateTime = Get-Date
Write-Host "Sync started at $StartDateTime" -ForegroundColor Red
while ($subscription.GetSynchronizationStatus() -ne "NotProcessing") {
    Write-Progress -Activity "Sync" -Status ( $subscription.GetSynchronizationStatus() )
}
Write-Host "Sync completed at $(Get-Date) and took $( (New-TimeSpan -Start $StartDateTime).Hours ) hours, $( (New-TimeSpan -Start $StartDateTime).Minutes ) minutes, $( (New-TimeSpan -Start $StartDateTime).Seconds ) seconds" -ForegroundColor Red

# Stop the WSUS Server Configuration Wizard from displaying.
$wsusConfig.OobeInitialized = $True
$wsusConfig.Save()

# All classifications selected to keep things simple.
Write-Host "Setting all classifications..."
Get-WsusClassification | Set-WsusClassification

# Products to get updates.
Get-WsusProduct | Set-WsusProduct -Disable  # Disable all of them first.
Write-Host "Setting products..."
$arrayProduct = @(
    "Windows XP Embedded",
    "Windows XP"
)
Get-WsusProduct | Where-Object -FilterScript {$_.Product.Title -in $arrayProduct} | Set-WsusProduct

# Sync again.
Write-Host "Syncing..."
$subscription = $wsus.GetSubscription()
$subscription.StartSynchronization()
$StartDateTime = Get-Date
Write-Host "Sync started at $StartDateTime" -ForegroundColor Red
while ($subscription.GetSynchronizationStatus() -ne "NotProcessing") {
    Write-Progress -Activity "Sync" -Status ( $subscription.GetSynchronizationStatus() )
}
Write-Host "Sync completed at $(Get-Date) and took $( (New-TimeSpan -Start $StartDateTime).Hours ) hours, $( (New-TimeSpan -Start $StartDateTime).Minutes ) minutes, $( (New-TimeSpan -Start $StartDateTime).Seconds ) seconds" -ForegroundColor Red

# Configure Default Approval Rule and apply.
Write-Host "Configuring the default automatic approval rule."
$rule = $wsus.GetInstallApprovalRules() | Where-Object {$_.Name -eq "Default Automatic Approval Rule"}
$rule.SetUpdateClassifications($wsus.GetUpdateClassifications())
$rule.Enabled = $True
$rule.Save()

Write-Host "Applying rule..."
$rule.ApplyRule()