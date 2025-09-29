# Use for copying the Windows XP I386 folder onto a HDD/SSD with a 64-bit CPU.
# Windows ADK 10.1.26100.2454 (December 2024)
# Windows PE add-on for Windows ADK 10.1.26100.2454 (December 2024)
# Use Windows PE add-on for the ADK, version 2004 for 32-bit Windows PE.
# https://learn.microsoft.com/en-us/windows/deployment/customize-boot-image?tabs=powershell
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-mount-and-customize?view=windows-11

#Requires -RunAsAdministrator
#Requires -Version 5.1

$StartDateTime = Get-Date
Write-Host "Script started at $StartDateTime" -ForegroundColor Red

# Windows XP ISO filename
$pathXPiso = "$PSScriptRoot\en_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73974.iso"

# Dell Precision M4700 Windows XP drivers pack
# See link below for list of contents:
# https://dl.dell.com/FOLDER02141122M/1/M4700-xp-A07-YH4YP.html
$pathDelldrivers = "$PSScriptRoot\M4700-xp-A07-YH4YP.CAB"

# List of cumulative updates in the CUs folder. KB names are in double quotes separated by commas.
# No need to include the SSU in this list.
$listCUs = @("KB5065426")

# List of optional components that will be added in the order listed.
$listOCs = @("WinPE-WMI", "WinPE-NetFX", "WinPE-Scripting", "WinPE-PowerShell", "WinPE-DismCmdlets", "WinPE-StorageWMI", "WinPE-SecureStartup", "WinPE-FMAPI", "WinPE-SecureBootCmdlets", "WinPE-EnhancedStorage")


# Constant Paths
$pathADKWinPE = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim")
$pathADKDism = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe")
$ADKInstallLocation = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10")
$ADKWinPELocation = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim")
$DandISetEnvPath = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\DandISetEnv.bat")

# Optional components folders
$pathOC = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs")
$pathOCen = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us")

# Paths relative to script location
$WinPEPath = "$PSScriptRoot\WinPE_amd64"
$pathMount = "$WinPEPath\mount"
$pathWimFile = "$WinPEPath\media\sources\boot.wim"
$pathCU = "$PSScriptRoot\CUs"
$pathXPUpdateFolder = "$PSScriptRoot\Post-SP3-Updates"
$pathXPUpdateList = "$PSScriptRoot\post-sp3-updates-list.txt"


# No point of continuing if the ISO is not present.
if ( !(Test-Path -Path $pathXPiso) ) {
    Write-Host "Windows XP ISO file not present! Exiting!" -ForegroundColor Yellow
    Exit
}

# Check if Windows ADK and PE add-on are installed
Write-Host "Checking if Windows ADK is installed..." -ForegroundColor DarkGreen
$ADKInstalled = Test-Path -Path "$ADKInstallLocation\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
if ($ADKInstalled) {
    Write-Host "  -- An installation of Windows ADK was found on device."
}
else {
    Write-Host "  -- An installation of Windows ADK was not found on the device." -ForegroundColor Yellow
    Exit
}

Write-Host "Checking if Windows ADK WinPE add-on is installed..." -ForegroundColor DarkGreen
$ADKWinPEInstalled = Test-Path -Path $ADKWinPELocation
if ($ADKWinPEInstalled) {
    Write-Host "  -- An installation of Windows ADK WinPE add-on was found on this device."
}
else {
    Write-Host "  -- An installation for Windows ADK WinPE add-on was NOT found on this device." -ForegroundColor Yellow
    Exit
}


# Delete existing WinPE folder and create a new one.
Write-Host "[+] Creating a working copy of Windows PE" -ForegroundColor DarkGreen
if (Test-Path -Path "$WinPEPath") {
    Write-Host "Deleting the existing WinPE folder..."
    Remove-Item -Path "$WinPEPath" -Recurse -Force
}
Write-Host "Creating new WinPE folder..." -ForegroundColor DarkGreen
cmd.exe /c """$DandISetEnvPath"" && copype amd64 $WinPEPath"

# Mount boot.wim to mount folder.
Write-Host "Mounting boot.wim..." -ForegroundColor DarkGreen
Mount-WindowsImage -Path "$pathMount" -ImagePath "$pathWimFile" -Index 1 -Verbose

# Add optional components to boot.wim
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-add-packages--optional-components-reference?view=windows-11#how-to-add-optional-components
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-add-packages--optional-components-reference?view=windows-11#winpe-optional-components
# For Windows 11: If you're launching Windows Setup from WinPE, make sure your WinPE image includes the WinPE-WMI and WinPE-SecureStartup optional components.
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-intro?view=windows-11#notes-on-running-windows-setup-in-windows-pe
foreach ($oc in $listOCs) {
    Write-Host "Adding $oc.cab" -ForegroundColor Cyan
    Add-WindowsPackage -Path "$pathMount" -PackagePath "$pathOC\$oc.cab"

    if (Test-Path -Path "$pathOCen\$oc`_en-us.cab") {
        Write-Host "Adding $oc`_en-us.cab" -ForegroundColor Cyan
        Add-WindowsPackage -Path "$pathMount" -PackagePath "$pathOCen\$oc`_en-us.cab"
    }
    
}

# Set the power scheme to high performance
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-mount-and-customize?view=windows-11#set-the-power-scheme-to-high-performance
$pathStartnetcmd = Join-Path -Path $pathMount -ChildPath "windows\system32\startnet.cmd"
Write-Host "Setting the power scheme to high-performance."
"powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" | Out-File -FilePath "$pathStartnetcmd" -Append -Encoding ascii

# Add cumulative update (CU) to boot image. CLOSE WINDOWS SANDBOX!
# Error message if Windows Sandbox is running:
# WARNING: Failed to add package
# WARNING: Add-WindowsPackage failed. Error code = 0x80070091
# Add-WindowsPackage : An error occurred applying the Unattend.xml file from the .msu package.
#
# Windows 11 24H2 updates at https://support.microsoft.com/en-us/help/5045988
# https://catalog.update.microsoft.com/
# https://learn.microsoft.com/en-us/windows/deployment/update/catalog-checkpoint-cumulative-updates
# https://learn.microsoft.com/en-us/windows/deployment/update/media-dynamic-update
# Add-WindowsPackage -PackagePath "<Path_to_CU_MSU_update>\<CU>.msu" -Path "<Mount_folder_path>" -Verbose
if ( (Test-Path -Path "$pathCU") -and ((Get-ChildItem -Path "$pathCU").Count -ne 0) -and ($listCUs.Count -gt 0) ) {
    Write-Host "Adding cumulative update(s)..." -ForegroundColor DarkGreen
    foreach ($cu in $listCUs) {
        if (Test-Path -Path "$pathCU\*$cu*") {
            Write-Host "Adding $cu" -ForegroundColor DarkCyan

            $nameCU = (Get-ChildItem -Path "$pathCU\*$cu*").Name
            $pathTemp = "$pathCU\$nameCU"
            Add-WindowsPackage -Path "$pathMount" -PackagePath "$pathTemp"
        }
        else {
            Write-Host "$cu does not exist!" -ForegroundColor Yellow
        }

    }
}
else {
    Write-Host "Cumulative updates folder does not exist or no updates to add." -ForegroundColor Yellow
}

# Perform component cleanup
Write-Host "Performing component cleanup..." -ForegroundColor DarkGreen
Start-Process "$pathADKDism" -ArgumentList " /Image:${pathMount} /Cleanup-image /StartComponentCleanup /Resetbase" -Wait -LoadUserProfile -NoNewWindow

# Mount the Windows XP ISO.
Write-Host "Mounting the ISO file." -ForegroundColor DarkGreen
$isoMountPointDriveLetter = (Mount-DiskImage -StorageType ISO -ImagePath $pathXPiso -ErrorAction Stop -PassThru | Get-Volume).DriveLetter
$pathISOi386 = $isoMountPointDriveLetter + ":" + "\I386"

# Copy I386 folder and its contents to the WinPE mount folder.
Write-Host "Copying $pathISOi386 to $pathMount" -ForegroundColor DarkGreen
Copy-Item -Path "$pathISOi386" -Destination "$pathMount\I386" -Recurse -Force

# Unmount the ISO.
 Write-Host "Unmounting the ISO image." -ForegroundColor DarkGreen
 Dismount-DiskImage -ImagePath $pathXPiso -ErrorAction Stop | Out-Null


 # Apply Windows XP updates.
 # Post-SP3-Updates folder with updates must be in the same location as this script.
 # Same goes with post-sp3-updates-list.txt file. Patch KB name each on a separate line. 
 # Used list from:
 # https://archive.org/details/windows-xp-sp-3-patches-updated
 # Downloaded patches straight from Microsoft. Some weren't present.
 # Slipstream patches into Windows XP install files:
 # https://support.microsoft.com/en-us/topic/how-to-integrate-software-updates-into-your-windows-installation-source-files-58beba8e-befa-91ae-63eb-d661e5910937
 if ( (Test-Path -Path $pathXPUpdateFolder) -and (Test-Path -Path $pathXPUpdateList) ) {
    Write-Host "Slipstreaming Windows XP updates..." -ForegroundColor DarkMagenta
    $listContent = Get-Content -Path $pathXPUpdateList
    foreach ($line in $listContent){
        $theUpdate = (Get-ChildItem -Path "$pathXPUpdateFolder\*$line*").FullName
        if ($null -ne $theUpdate) {
            Write-Host "Adding update $line"
            Start-Process "$theUpdate" -ArgumentList "/integrate:$pathMount /passive /norestart" -Wait -LoadUserProfile -NoNewWindow
        }
        else {
            Write-Host "$line does not exists!" -ForegroundColor Yellow
        }
    }
    Write-Host "Slipstreaming Windows XP updates...completed" -ForegroundColor DarkMagenta
 }


# Drivers MUST BE IN SUBFOLDERS UNDER $OEM$\$1\DRIVERS
# https://msfn.org/board/topic/19792-textmode-massstoragedrivers-method/
# RAID/SATA DRIVERS MUST BE UNDER:
#   $OEM$
#   $OEM$\TEXTMODE
#   I386\$OEM$
#   I386\$OEM$\TEXTMODE
$oemDriverspath = ""
if (Test-Path -Path $pathDelldrivers) {
    # Check Authenticode signature
    if ( (Get-AuthenticodeSignature -FilePath $pathDelldrivers).Status -ne "Valid" ) {
        Write-Host "Invalid signature! Skipping extraction!" -ForegroundColor Yellow
        Break
    }
    else {
        # Delete M4700 folder and it's contents if it exists
        if (Test-Path -Path "$PSScriptRoot\M4700") {
            Remove-Item -Path "$PSScriptRoot\M4700" -Recurse -Force
        }
        # Extract the drivers
        Start-Process "expand.exe" -ArgumentList "$pathDelldrivers -F:* $PSScriptRoot" -Wait -LoadUserProfile

        $tempPath = "$pathMount" + '\$OEM$\$1\DRIVERS'
        New-Item -Path $tempPath -ItemType Directory
        Copy-Item -Path "$PSScriptRoot\M4700\xp\x86\*" -Destination $tempPath -Recurse -Force

        $pathStoragedrivers = "$PSScriptRoot\M4700\xp\x86\storage\404F9_A00-00\Production\XP-x86"
        Copy-Item -Path "$pathStoragedrivers\*" -Destination "$pathMount\`$OEM$" -Recurse -Force
        Copy-Item -Path "$pathStoragedrivers" -Destination "$pathMount\`$OEM$\TEXTMODE" -Recurse -Force
        Copy-Item -Path "$pathStoragedrivers" -Destination "$pathMount\I386\`$OEM$" -Recurse -Force
        Copy-Item -Path "$pathStoragedrivers" -Destination "$pathMount\I386\`$OEM$\TEXTMODE" -Recurse -Force

        Set-Location "$pathMount\`$OEM$\`$1"
        $tempObj = (Get-ChildItem * -Recurse -Include "*.inf") | Select-Object Directory -Unique
        $oemDriverspath = "OemPnPDriversPath=`""
        foreach ($the_folder in $tempObj){
            if ($null -ne $the_folder.Directory) {
                # Write-Host ($the_folder.Directory | Resolve-Path -Relative)
                $temp = ($the_folder.Directory | Resolve-Path -Relative)
                $temp = $temp.Substring(2)
                $oemDriverspath += "$temp;"
            } 
        }
        $oemDriverspath =  $oemDriverspath.Remove($oemDriverspath.Length - 1, 1)  # Removes the last ;
        $oemDriverspath = $oemDriverspath + '"'
        Set-Location $PSScriptRoot

        Remove-Item -Path "$PSScriptRoot\M4700" -Recurse -Force
    }
}


# Copy TXTSETUP.SIF to the WinPE mount folder.
# Add two lines under [SetupData] section:
# BootPath = "\I386\"
# SetupSourceDevice = "\Device\Harddisk0\Partition1"
$pathTxtsetup = "$pathMount\I386\TXTSETUP.SIF"
Write-Host "Copying $pathTxtsetup to $pathMount" -ForegroundColor DarkGreen
Copy-Item -Path "$pathTxtsetup" -Destination "$pathMount"

$tempText = @"

BootPath = "\I386\"
SetupSourceDevice = "\Device\Harddisk0\Partition1"
"@
$pathTxtsetup = "$pathMount\TXTSETUP.SIF"
if ( Select-String -Path $pathTxtsetup -Pattern '\[SetupData\]' -Quiet ) {
    $tempObject = Select-String -Path $pathTxtsetup -Pattern '\[SetupData\]'
    if ( !($tempObject -is [array]) ) {
        Write-Host "Adding BootPath and SetupSourceDevice to TXTSETUP.SIF" -ForegroundColor DarkGreen
        Set-ItemProperty -Path "$pathTxtsetup" -Name IsReadOnly -Value $false
        $fileContent = Get-Content -Path "$pathTxtsetup"
        $fileContent[$tempObject.LineNumber - 1] += $tempText
        $fileContent | Set-Content -Path "$pathTxtsetup"
        Set-ItemProperty -Path "$pathTxtsetup" -Name IsReadOnly -Value $true
    }
    else {
        Write-Host "Multiple [SetupData] matches found!" -ForegroundColor Yellow
        Write-Host "This should not happen!" -ForegroundColor Yellow
    }
}


# Create winnt.sif in I386 for unattended installation
$winntSIF = @"
; https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2003/cc757642(v=ws.10)
[Data]
;Installs Windows to the first available partition that has adequate space for a Windows installation and does not already contain an installed version of Windows.
AutoPartition = 1

;Informs the Windows Setup Loader that an unattended installation is running directly from the Windows product CD.
MsDosInitiated = 0

;Informs the Windows Setup Loader that an unattended installation is running directly from the Windows product CD.
UnattendedInstall = Yes

[Unattended]
;Defines the unattended mode to use during the final (GUI-mode) stage of Setup.
;UnattendMode = DefaultHide | FullUnattended | GuiAttended | ProvideDefault | ReadOnly
UnattendMode = FullUnattended

;Specifies whether Setup installs its files from distribution folders.
OemPreinstall = Yes

;Specifies whether the user must accept the End-User License Agreement (EULA) included with Windows.
OemSkipEula = Yes

;Determines the installation folder in which you install Windows.
TargetPath=\WINDOWS

;Specifies how to process unsigned drivers during unattended installation.
;DriverSigningPolicy = Block | Warn | Ignore
;The default value is Warn.
DriverSigningPolicy = Ignore

;Specifies the path to the \`$OEM$ folder (containing OEM files) if it does not exist under the i386 folder of the distribution share.
;OemFilesPath = path_to_`$OEM`$_folder

;Specifies the path to one or more folders that contain Plug and Play drivers not distributed in Drivers.cab on the Windows product CD.
;You must also use the entry OEMPreinstall = Yes.
;The length of the OemPnPDriversPath entry in the answer file must not exceed 4096 characters.
;You cannot use environment variables to specify the location of a folder.
;OemPnPDriversPath = folder_1_on_system_drive[;folder_2_on_system_drive]...
$oemDriverspath

;Specifies whether Setup skips Windows Welcome or Mini-Setup when preinstalling Windows XP Home Edition or Windows XP Professional by using the CD Boot method.
;UnattendSwitch = Yes | No
UnattendSwitch = Yes

[GuiUnattended]
;Set AdminPassword to something or setup will stop the process and ask for one.
AdminPassword = *

AutoLogon = Yes
AutoLogonCount = 1

;Enables unattended installation to skip the Regional and Language Options page in the final (GUI-mode) stage of Setup.
;OEMSkipRegional = 0 | 1
OEMSkipRegional = 1

;Enables unattended installation to skip the Welcome page in the final (GUI-mode) stage of Setup.
;You must also set OemPreinstall = Yes if you use this entry.
;OemSkipWelcome = 0 | 1
OemSkipWelcome = 1


;Specifies the time zone of the computer.
;https://learn.microsoft.com/en-us/previous-versions/orphan-topics/ws.10/cc755725(v=ws.10)?redirectedfrom=MSDN#timezone
;TimeZone = index
;4 = Pacific Standard Time
TimeZone = 4

[UserData]
ProductKey="XCYBK-2B3KV-G8T8F-WXJM7-WCTYT"
FullName = "Home"
OrgName = "Home"
ComputerName = *

[RegionalSettings]
LanguageGroup=1
SystemLocale=00000409
UserLocale=00000409
InputLocale=0409:00000409

[Identification]
JoinWorkgroup=WORKGROUP

[Networking]
InstallDefaultComponents = Yes


;The [OEMBootFiles] section contains entries for specifying OEM-supplied boot files. This section is valid only if you use
;the entry OemPreinstall = Yes in the [Unattend] section and you place the files listed here in the \`$OEM$\Textmode folder;
;of the distribution share.
;https://learn.microsoft.com/en-us/previous-versions/orphan-topics/ws.10/cc755793(v=ws.10)?redirectedfrom=MSDN
;
; COMMENT OUT ALL THE LINES BELOW IF `$OEM$ DOESN'T EXISTS OR IF YOU ONLY PLAN ON USING ATA!
[OEMBootFiles]
iaahci.cat
iaAHCI.inf
iastor.cat
iaStor.inf
iaStor.sys
TXTSETUP.OEM

[MassStorageDrivers]
; iaAHCI.inf
"Intel(R) ICH7R/DH SATA AHCI Controller" = "OEM"
"Intel(R) ICH7M/MDH SATA AHCI Controller" = "OEM"
"Intel(R) ICH9M-E/M SATA AHCI Controller" = "OEM"
"Intel(R) ICH10D/DO SATA AHCI Controller" = "OEM"
"Intel(R) ICH10R SATA AHCI Controller" = "OEM"
"Intel(R) 5 Series 4 Port SATA AHCI Controller" = "OEM"
"Intel(R) 5 Series 6 Port SATA AHCI Controller" = "OEM"
"Intel(R) 5 Series/3400 Series SATA AHCI Controller" = "OEM"
"Intel(R) Desktop/Workstation/Server Express Chipset SATA AHCI Controller" = "OEM"
"Intel(R) Mobile Express Chipset SATA AHCI Controller" = "OEM"
"Intel(R) 7 Series/C216 Chipset Family SATA AHCI Controller" = "OEM"
"Intel(R) 7 Series Chipset Family SATA AHCI Controller" = "OEM"

; iaStor.inf
"Intel(R) ICH7R/DH SATA RAID Controller" = "OEM"
"Intel(R) ICH7MDH SATA RAID Controller" = "OEM"
"Intel(R) Desktop/Workstation/Server Express Chipset SATA RAID Controller" = "OEM"
"Intel(R) Mobile Express Chipset SATA RAID Controller" = "OEM"
"@
Write-Host "Creating $pathMount\I386\winnt.sif" -ForegroundColor DarkGreen
Out-File -Encoding ascii -InputObject $winntSIF -FilePath "$pathMount\I386\winnt.sif"


 # Create diskpart script.
 # https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/diskpart
 $theScript = @"
select disk 0
clean

rem Create partition to copy Windows XP setup files to.
rem Partition size is all of the available space.
create partition primary
active
format fs=ntfs quick
assign letter=Z

exit
"@
Write-Host "Creating 1-partition-disk-0.txt in $pathMount" -ForegroundColor DarkGreen
Out-File -Encoding ascii -InputObject $theScript -FilePath "$pathMount\1-partition-disk-0.txt"

# Create batch file that partitions the disk, copies the files, and runs bootsect.
$theScript = @"
rem THIS SCRIPT WILL DELETE ALL PARTITIONS AND QUICK FORMAT THE HDD/SSD!
rem Press Ctrl+C to abort!

pause

rem Running diskpart...
diskpart /s X:\1-partition-disk-0.txt

rem Copying files...

robocopy "X:\I386" "Z:\I386" /e
robocopy "X:\`$OEM$" "Z:\`$OEM$" /e

copy "X:\I386\NTDETECT.COM" "Z:\NTDETECT.COM"
copy "X:\I386\SETUPLDR.BIN" "Z:\NTLDR"
copy "X:\TXTSETUP.SIF" "Z:\TXTSETUP.SIF"

bootsect /nt52 Z: /mbr /force

wpeutil reboot

"@
Write-Host "Creating prep-install.bat in $pathMount" -ForegroundColor DarkGreen
Out-File -Encoding ascii -InputObject $theScript -FilePath "$pathMount\prep-install.bat"
# Add entry in startnet.cmd so the script will automatically run.
"X:\prep-install.bat" | Out-File -FilePath "$pathStartnetcmd" -Append -Encoding ascii

# Unmount boot image and save changes
Write-Host "Unmounting and saving changes to boot.wim..." -ForegroundColor DarkGreen
Dismount-WindowsImage -Path "$pathMount" -Save -Verbose

Write-Host "Script completed at $(Get-Date) and took $( (New-TimeSpan -Start $StartDateTime).Hours ) hours, $( (New-TimeSpan -Start $StartDateTime).Minutes ) minutes, $( (New-TimeSpan -Start $StartDateTime).Seconds ) seconds" -ForegroundColor Red

# Useful commands to run.
Write-Host "Run:"
Write-Host "makewinpemedia /ufd `"$WinPEPath`" <USB Flash Drive Letter>:" -ForegroundColor DarkCyan
Write-Host "Mount/Dismount the Windows PE boot.wim:"
Write-Host "Mount-WindowsImage -ImagePath `"$pathWimFile`" -Path `"$pathMount`" -Index 1" -ForegroundColor DarkCyan
Write-Host "Dismount-WindowsImage -Path `"$pathMount`" -Discard" -ForegroundColor DarkCyan
Write-Host "Dismount-WindowsImage -Path `"$pathMount`" -Save" -ForegroundColor DarkCyan
