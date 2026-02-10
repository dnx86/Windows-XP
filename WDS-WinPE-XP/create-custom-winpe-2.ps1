# Generates a winpe.wim file with drivers, optional components, and updates for use with Windows WDS.
# Customize Windows PE boot image
# https://learn.microsoft.com/en-us/windows/deployment/customize-boot-image?tabs=powershell
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-mount-and-customize?view=windows-11
#Requires -RunAsAdministrator
#Requires -Version 5.1

$StartDateTime = Get-Date
Write-Host "Script started at $StartDateTime" -ForegroundColor Red

# List of cumulative updates in the CUs folder. KB names are in double quotes separated by commas.
# DO NOT INCLUDE THE SSU HERE. It must be present in the CUs folder though.
$listCUs = @("KB5074105")

# Windows XP ISO filename
$pathXPiso = "$PSScriptRoot\en_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73974.iso"
# No point of continuing if the ISO is not present.
if ( !(Test-Path -Path $pathXPiso) ) {
    Write-Host "Windows XP ISO file not present! Exiting!" -ForegroundColor Yellow
    Exit 1
}

# Constant Paths -  DO NOT REMOVE!
$pathADKDism = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe")
$ADKInstallLocation = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10")
$ADKWinPELocation = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim")
$DandISetEnvPath = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\DandISetEnv.bat")

# Paths relative to this script's location
$WinPEPath = "$PSScriptRoot\WinPE_amd64"
$pathMount = "$WinPEPath\mount"
$pathWimFile = "$WinPEPath\media\sources\boot.wim"
$pathCU = "$PSScriptRoot\WinPE-CUs"
$pathDrivers = "$PSScriptRoot\WinPE-Drivers"
$pathShareXP = "$PSScriptRoot\windows-xp"
$pathShareScripts = "$pathShareXP\scripts"
$pathSOFTWARE = "$PSScriptRoot\SOFTWARE"
$pathDellXPCabDrivers = "$PSScriptRoot\DellXPCabDrivers"


## BEGIN FUNCTIONS ##
function AdkPeInstalled {
    # Check if Windows ADK is installed.
    $ADKInstalled = Test-Path -Path "$ADKInstallLocation\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"

    # Check if Windows ADK WinPE add-on is installed
    $ADKWinPEInstalled = Test-Path -Path $ADKWinPELocation

    if ($ADKInstalled -and $ADKWinPEInstalled) {
        return $true
    }
    else {
        return $false
    }
}

function DriverFilesPresent {
    param (
        [Parameter(Mandatory)]
        [string]$folderDrivers
    )

    if (-not (Test-Path $folderDrivers)) {
        # Returns false if the folder does not exist.
        return $false
    }
    elseif ( (Get-ChildItem -Path $folderDrivers).Count -eq 0 ) {
        # Returns false if it is an empty folder.
        return $false
    }
    else {
        # https://learn.microsoft.com/en-us/windows-hardware/drivers/install/components-of-a-driver-package
        # Checks if INF and catalog files are present. See link above.
        $numInf = (Get-ChildItem -Path $folderDrivers -Recurse -Filter "*.inf").Count
        $numCat = (Get-ChildItem -Path $folderDrivers -Recurse -Filter "*.cat").Count

        if (($numInf -gt 0) -and ($numCat -gt 0)) {
            return $true
        }
        else {
            return $false
        }
    }   
}

function Add-CUs {
    param (
        [Parameter(Mandatory)]
        [string]$folderCUs,

        [Parameter(Mandatory)]
        [string[]]$theList,

        [Parameter(Mandatory)]
        [string]$folderMount
    )
    
    if (-not ($theList)) {
        Write-Host "Cumulative update list is empty!" -ForegroundColor DarkRed
    }
    elseif (-not (Test-Path -Path $folderCUs)) {
        Write-Host "$folderCUs does not exist!" -ForegroundColor DarkRed
    }
    elseif ( (Get-ChildItem -Path $folderCUs -Filter "*.msu").Count -eq 0 ) {
        Write-Host "$folderCUs is empty!" -ForegroundColor DarkRed
    }
    else {
        Write-Host "Adding cumulative update(s)..." -ForegroundColor DarkGreen
        foreach ($cu in $theList) {
            if (Test-Path -Path "$folderCUs\*$cu*") {
                Write-Host "Adding $cu" -ForegroundColor DarkCyan

                $nameCU = (Get-ChildItem -Path "$folderCUs\*$cu*").Name
                $pathTemp = Join-Path -Path $folderCUs -ChildPath $nameCU
                Add-WindowsPackage -Path $folderMount -PackagePath $pathTemp
            }
            else {
                Write-Host "$cu does not exist!" -ForegroundColor DarkRed
            }
        }
    }

    return
}

function Add-OCs {
    param (
        [Parameter(Mandatory)]
        [string[]]$theList
    )

    # Optional components folders -  DO NOT REMOVE!
    $pathOC = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs")
    $pathOCen = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us")

    if ( (-not (Test-Path -Path $pathOC)) -or (-not (Test-Path -Path $pathOCen)) ) {
        Write-Host "Missing optional components folder(s)!" -ForegroundColor DarkRed
        return
    }

    foreach ($oc in $theList) {
        if (Test-Path -Path "$pathOC\$oc.cab") {
            # Add language-neutral OC first.
            Write-Host "Adding $oc.cab" -ForegroundColor Cyan
            Add-WindowsPackage -Path "$pathMount" -PackagePath "$pathOC\$oc.cab" > $null
        }

        if (Test-Path -Path "$pathOCen\$oc`_en-us.cab") {
            # Add at least one of its associated language-specific packages next.
            Write-Host "Adding $oc`_en-us.cab" -ForegroundColor Cyan
            Add-WindowsPackage -Path $pathMount -PackagePath "$pathOCen\$oc`_en-us.cab" > $null
        }
    }
    return
}

function Create-DiskpartScript {
    param (
        [int]$diskNumber = 0,

        [string]$diskLetter = 'Z',

        [Parameter(Mandatory)]
        [string]$folderScripts,

        [string]$scriptName = "diskpart-script.txt"
    )
 # Create diskpart script.
 # https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/diskpart
 $theScript = @"
select disk $diskNumber
clean

rem Create partition to copy Windows XP setup files to.
rem Partition size is all of the available space.
create partition primary
active
format fs=ntfs quick
assign letter=$diskLetter

exit
"@

$pathScript = "$folderScripts\$scriptName"
if (Test-Path -Path $pathScript) {
    Remove-Item -Path $pathScript -Force
}
Out-File -Encoding ascii -InputObject $theScript -FilePath $pathScript

return
}

function Customize-Startnet {
    param (
        [string]$nuDeviceName = 'Y',

        [Parameter(Mandatory)]
        [string]$nuComputerName,

        [Parameter(Mandatory)]
        [string]$nuShareName,

        [Parameter(Mandatory)]
        [string]$nuUser,

        [Parameter(Mandatory)]
        [string]$nuPassword
    )

    $pathStartnetcmd = Join-Path -Path $pathMount -ChildPath "windows\system32\startnet.cmd"

    # Set the power scheme to high performance
    # https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-mount-and-customize?view=windows-11#set-the-power-scheme-to-high-performance
    "powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" | Out-File -FilePath "$pathStartnetcmd" -Append -Encoding ascii

    $listCommands = @(
        'wpeutil InitializeNetwork'
        'powershell -NoProfile -NoLogo -Command "& {while (-not (Test-Connection -Quiet -ErrorAction SilentlyContinue 10.10.10.1)) { Start-Sleep -Seconds 1 }}"'  # DO NOT REMOVE! Some network adapters are slow when getting an IP address.
        "net use ${nuDeviceName}: \\${nuComputerName}\${nuShareName} /user:${nuUser} ${nuPassword}"  # https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/gg651155(v=ws.11)
        "powershell -NoProfile -NoLogo -Command `"& {while (-not (Test-Path -Path X:\install-xp.ps1)) { xcopy ${nuDeviceName}:\scripts\* X:\ }}`""
        'powershell -NoProfile -NoLogo -ExecutionPolicy Bypass -File "X:\install-xp.ps1"'  # install-xp.ps1 ties all the scripts together.
    )
    if ($listCommands) {
        Write-Host "Appending commands to startnet.cmd..." -ForegroundColor DarkGreen
        foreach ($command in $listCommands) {
            $command | Out-File -FilePath "$pathStartnetcmd" -Append -Encoding ascii
        }
    }
}
## END FUNCTIONS ##


# Check if Windows ADK and PE add-on are installed
if ( -not (AdkPeInstalled) ) {
    Write-Host "Windows ADK and/or WinPE add-on not installed! Exiting!" -ForegroundColor Yellow
    Exit 1
}

# Delete existing WinPE folder and create a new one.
Write-Host "[+] Creating a working copy of Windows PE" -ForegroundColor DarkGreen
if (Test-Path -Path $WinPEPath) {
    Write-Host "Deleting the existing WinPE folder..." -ForegroundColor Yellow
    Remove-Item -Path $WinPEPath -Recurse -Force
}
Write-Host "Creating new WinPE folder..." -ForegroundColor DarkGreen
cmd.exe /c """$DandISetEnvPath"" && copype amd64 $WinPEPath"

# Mount boot.wim to mount folder.
Write-Host "Mounting boot.wim..." -ForegroundColor DarkGreen
Mount-WindowsImage -Path $pathMount -ImagePath $pathWimFile -Index 1 > $null

# Add drivers to boot image (optional)
# Dell Command | Deploy WinPE Driver Packs
# https://www.dell.com/support/kbdoc/en-us/000107478/dell-command-deploy-winpe-driver-packs
# Copy Dell WinPE 11 driver pack to the Drivers directory and expand (see example below)
# expand -f:* .\WinPE11.0-Drivers-A06-336TP.cab .
if (DriverFilesPresent($pathDrivers)) {
    Write-Host "Adding drivers..." -ForegroundColor DarkGreen
    Add-WindowsDriver -Path $pathMount -Driver $pathDrivers -Recurse
}
else {
    Write-Host "Drivers folder does not exists, is empty, or no drivers files present." -ForegroundColor Yellow
}

# Add optional components to boot image
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-add-packages--optional-components-reference?view=windows-11#how-to-add-optional-components
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-add-packages--optional-components-reference?view=windows-11#winpe-optional-components
# For Windows 11: If you're launching Windows Setup from WinPE, make sure your WinPE image includes the WinPE-WMI and WinPE-SecureStartup optional components.
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-intro?view=windows-11#notes-on-running-windows-setup-in-windows-pe
#
# List of optional components that will be added in the order listed.
$listOCs = @("WinPE-WMI", "WinPE-NetFX", "WinPE-Scripting", "WinPE-PowerShell", "WinPE-DismCmdlets", "WinPE-StorageWMI", "WinPE-SecureStartup", "WinPE-FMAPI", "WinPE-SecureBootCmdlets", "WinPE-EnhancedStorage")
if ($listOCs) {
    Add-OCs -theList $listOCs
}

# Customize startnet.cmd
# Assume Y: is the default and appropriate permissions are set for the share folder.
Customize-Startnet -nuComputerName '10.10.10.1' -nuShareName 'shares\windows-xp' -nuUser 'test12' -nuPassword 'Averysecurepassword!'


# Add cumulative update (CU) to boot image. CLOSE WINDOWS SANDBOX!
# Windows 11 25H2 updates at https://support.microsoft.com/en-us/help/5065323
# Windows 11 24H2 updates at https://support.microsoft.com/en-us/help/5045988
# https://catalog.update.microsoft.com/
# https://learn.microsoft.com/en-us/windows/deployment/update/catalog-checkpoint-cumulative-updates
# https://learn.microsoft.com/en-us/windows/deployment/update/media-dynamic-update
#
# Check if Windows Sandbox is running.
$sandboxWarning = @'
Windows Sandbox is running! It causes the error below when applying cumulative updates:
WARNING: Add-WindowsPackage failed. Error code = 0x80070091
Add-WindowsPackage : An error occurred applying the Unattend.xml file from the .msu package.

'@
$sandboxRunning = ([boolean](Get-Process -Name "WindowsSandboxRemoteSession" -ErrorAction SilentlyContinue)) -or ([boolean](Get-Process -Name "WindowsSandboxServer" -ErrorAction SilentlyContinue))
if ($sandboxRunning) {
    Write-Host $sandboxWarning -ForegroundColor DarkRed
    Write-Host "Skipping cumulative updates!" -ForegroundColor Red
}
elseif ($listCUs) {
    # Add CUs.
    Add-CUs -folderCUs $pathCU -theList $listCUs -folderMount $pathMount
}
else {
    Write-Host "No CUs to add!" -ForegroundColor Yellow
}

# Perform component cleanup
Write-Host "Performing component cleanup..."
Start-Process "$pathADKDism" -ArgumentList " /Image:${pathMount} /Cleanup-image /StartComponentCleanup /Resetbase" -Wait -LoadUserProfile -NoNewWindow


# Create the windows-xp folder.
# After this script finishes, copy this folder to the network share folder.
if (Test-Path -Path $pathShareXP) {
    Remove-Item -Path $pathShareXP -Recurse -Force
}
New-Item -Path $pathShareXP -ItemType Directory > $null
New-Item -Path $pathShareScripts -ItemType Directory > $null

# Mount Windows XP ISO and copy the I386 folder to the windows-xp folder.
# Mount the Windows XP ISO.
Write-Host "Mounting the ISO file." -ForegroundColor DarkGreen
$isoMountPointDriveLetter = (Mount-DiskImage -StorageType ISO -ImagePath $pathXPiso -ErrorAction Stop -PassThru | Get-Volume).DriveLetter
$pathISOi386 = $isoMountPointDriveLetter + ":" + "\I386"

# Copy I386 folder and its contents to the WinPE mount folder.
Write-Host "Copying $pathISOi386 to $pathShareXP" -ForegroundColor DarkGreen
Copy-Item -Path "$pathISOi386" -Destination "$pathShareXP\I386" -Recurse -Force
if (Test-Path -Path "$pathShareXP\I386\winnt.sif") {
    Remove-Item -Path "$pathShareXP\I386\winnt.sif" -Force  # Remove winnt.sif so customized one can be used.
}

if (Test-Path -Path "$PSScriptRoot\TXTSETUP.SIF") {
    Remove-Item -Path "$PSScriptRoot\TXTSETUP.SIF" -Force
}
Copy-Item -Path "$pathShareXP\I386\TXTSETUP.SIF" -Destination $PSScriptRoot


# Unmount the ISO.
 Write-Host "Unmounting the ISO image." -ForegroundColor DarkGreen
 Dismount-DiskImage -ImagePath $pathXPiso -ErrorAction Stop > $null

 # Copy the SOFTWARE folder (if it exists and is not empy) to the windows-xp folder.
 $pathSOFTWARE
 if ( (Test-Path -Path $pathSOFTWARE) -and (Get-ChildItem -Path $pathSOFTWARE).Count -gt 0 ) {
    Copy-Item -Path $pathSOFTWARE -Destination $pathShareXP -Recurse
 }


# Create diskpart script in winpe directory at $pathMount.
Write-Host "Creating diskpart-script.txt in $pathShareScripts" -ForegroundColor DarkGreen
Create-DiskpartScript -folderScripts $pathShareScripts

# Create system specific folders in windows-xp using scripts found in $PSScriptRoot.
# System specific Windows batch scripts created in the winpe directory at $pathMount.
# pathDellDriverCab can be just the file name.
$arrayComputers = @(
    @{
        modelName = 'OptiPlex'
        modelNumber = '990'
        pathDellDriverCab = "990-xp-A11-HX3XP.CAB"
        storageReleaseId = '3H23X_A07-00'
    }

    @{
        modelName = 'OptiPlex'
        modelNumber = '9010'
        pathDellDriverCab = "9010-xp-A05-8YR57.CAB"
        storageReleaseId = 'PM7TD_A01-00'
        pathDriversMisc = "$PSScriptRoot\ExtraDrivers"
    }

    @{
        modelName = 'Precision'
        modelNumber = 'M4700'
        pathDellDriverCab = "M4700-xp-A07-YH4YP.CAB"
        storageReleaseId = '404F9_A00-00'
    }
)

$theScriptComputers = ""
foreach ($computer in $arrayComputers) {
    # Loop through the array of hashtables.
    $params = @{
        pathMount = $pathMount
        pathShareXP = $pathShareXP
        pathShareScripts = $pathShareScripts
        modelName = $($computer.modelName)
        modelNumber = $($computer.modelNumber)
        pathDellDriverCab = "$pathDellXPCabDrivers\$($computer.pathDellDriverCab)"
        storageReleaseId = $($computer.storageReleaseId)
        pathDriversMisc = & {if (-not([string]::IsNullOrWhiteSpace($($computer.pathDriversMisc)))) {return $($computer.pathDriversMisc)}}
    }
    Write-Host "$($computer.modelName) $($computer.modelNumber)" -ForegroundColor DarkYellow
    & "$PSScriptRoot\create-xp-install2.ps1" @params
    $theScriptComputers += "    `"$($computer.modelName) $($computer.modelNumber)`"" + ' ' + "{Write-Host `$theModel `" detected! Automatic Windows XP installation will begin...`"; X:\install-windows-xp-$($computer.modelName)-$($computer.modelNumber).bat; break }" + [Environment]::NewLine
}

# Create Windows XP install scripts and files for Optiplex XE2.
$params = @{
    pathMount = $pathMount
    pathShareXP = $pathShareXP
    pathShareScripts = $pathShareScripts
    modelName = "OptiPlex"
    modelNumber = "XE2"
    pathDellDriverCab = $null
    storageReleaseId = $null
    pathDriversMisc = "$PSScriptRoot\XE2-Drivers"
}
Write-Host "$($params.modelName) $($params.modelNumber)" -ForegroundColor DarkYellow
& "$PSScriptRoot\create-xp-install2.ps1" @params
$theScriptComputers += "    `"$($params.modelName) $($params.modelNumber)`"" + ' ' + "{Write-Host `$theModel `" detected! Automatic Windows XP installation will begin...`"; X:\install-windows-xp-$($params.modelName)-$($params.modelNumber).bat; break }" + [Environment]::NewLine

# Create Windows XP install scripts and files for HP Z420 Workstation.
# Use .Replace(' ', '-') for modelNumbers with spaces in them.
$params = @{
    pathMount = $pathMount
    pathShareXP = $pathShareXP
    pathShareScripts = $pathShareScripts
    modelName = "HP"
    modelNumber = "Z420 Workstation"
    pathDellDriverCab = $null
    storageReleaseId = $null
    pathDriversMisc = "$PSScriptRoot\Z420-Drivers"
}
Write-Host "$($params.modelName) $($params.modelNumber)" -ForegroundColor DarkYellow
& "$PSScriptRoot\create-xp-install2.ps1" @params
$theScriptComputers += "    `"$($params.modelName) $($params.modelNumber)`"" + ' ' + "{Write-Host `$theModel `" detected! Automatic Windows XP installation will begin...`"; X:\install-windows-xp-$($params.modelName)-$(($params.modelNumber).Replace(' ', '-')).bat; break }" + [Environment]::NewLine

# Create a Powershell script to detect the model and run the appropriate script.
# This script ties it all together.
#
$theScript = @"
`$theModel = (Get-CimInstance -ClassName Win32_ComputerSystem).Model
Write-Host `$theModel
switch (`$theModel) {
$theScriptComputers
    Default { Write-Host `$theModel " not on the automatic network install list!"; powershell }
}
"@
Out-File -Encoding ascii -InputObject $theScript -FilePath "$pathShareScripts\install-xp.ps1"

# Create Windows XP install scripts and files with AHCI.
$params = @{
    pathMount = $pathMount
    pathShareXP = $pathShareXP
    pathShareScripts = $pathShareScripts
    modelName = "Vanilla"
    modelNumber = "Windows-XP-AHCI"
    pathDellDriverCab = $null
    storageReleaseId = $null
    pathDriversMisc = "$PSScriptRoot\Vanilla-XP-Drivers"
}
Write-Host "$($params.modelName) $($params.modelNumber)" -ForegroundColor DarkYellow
& "$PSScriptRoot\create-xp-install2.ps1" @params

# Create Windows XP install scripts and files for IDE.
$params = @{
    pathMount = $pathMount
    pathShareXP = $pathShareXP
    pathShareScripts = $pathShareScripts
    modelName = "Vanilla"
    modelNumber = "Windows-XP-IDE"
    useAhci = $false
}
Write-Host "$($params.modelName) $($params.modelNumber)" -ForegroundColor DarkYellow
& "$PSScriptRoot\create-xp-install2.ps1" @params


if (Test-Path -Path "$PSScriptRoot\TXTSETUP.SIF") {
    Remove-Item -Path "$PSScriptRoot\TXTSETUP.SIF" -Force
}

# Unmount boot image and save changes
Write-Host "Unmounting and saving changes to boot.wim..." -ForegroundColor DarkGreen
Dismount-WindowsImage -Path $pathMount -Save -Verbose

$timestamp = Get-Date $StartDateTime -Format "yyyy-MM-dd_HHmm"
# Copy the boot.wim file to $PSScriptRoot
Copy-Item -Path $pathWimFile -Destination "$PSScriptRoot\boot-$timestamp.wim"

# Create windows-xp.zip in $PSScriptRoot to copy over to the network share.
$params = @{
    Path = $pathShareXP
    DestinationPath = "$PSScriptRoot\windows-xp-$timestamp.zip"
    CompressionLevel = "NoCompression"
}
Compress-Archive @params



Write-Host "Script completed at $(Get-Date) and took $( (New-TimeSpan -Start $StartDateTime).Hours ) hours, $( (New-TimeSpan -Start $StartDateTime).Minutes ) minutes, $( (New-TimeSpan -Start $StartDateTime).Seconds ) seconds" -ForegroundColor Red

# Useful commands to run.
Write-Host "Run:"
Write-Host "makewinpemedia /ufd `"$WinPEPath`" <USB Flash Drive Letter>:" -ForegroundColor DarkCyan
Write-Host "makewinpemedia /iso `"$WinPEPath`" `"$PSScriptRoot\winpe.iso`"" -ForegroundColor DarkCyan
Write-Host "Mount/Dismount the Windows PE boot.wim:"
Write-Host "Mount-WindowsImage -ImagePath `"$pathWimFile`" -Path `"$pathMount`" -Index 1" -ForegroundColor DarkCyan
Write-Host "Dismount-WindowsImage -Path `"$pathMount`" -Discard" -ForegroundColor DarkCyan
Write-Host "Dismount-WindowsImage -Path `"$pathMount`" -Save" -ForegroundColor DarkCyan
