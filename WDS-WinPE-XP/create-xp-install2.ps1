# See below if using this script for a different DELL system:
# READ AND UNDERSTAND THIS SCRIPT FULLY PRIOR TO MAKING CHANGES AND RUNNING!
# $pathDelldrivers - MUST be a CAB file.
# Ctrl+f CHANGE HERE!
# Edit OEMBootFiles and MassStorageDrivers sections in $winntSIF.

#Requires -Version 5.1

param(
    [string]$shareLetter = 'Y',

    [string]$diskLetter = 'Z',

    [Parameter(Mandatory)]
    [string]$pathMount,

    [Parameter(Mandatory)]
    [string]$pathShareXP,

    [Parameter(Mandatory)]
    [string]$pathShareScripts,

    [string]$diskNumber = 0,

    [string]$pathDriversMisc = $null,

    [Parameter(Mandatory)]
    [string]$modelName,

    [Parameter(Mandatory)]
    [string]$modelNumber,

    [string]$pathDellDriverCab = $null,

    [string]$storageReleaseId = $null,

    [bool]$useAhci = $true
)


$StartDateTime = Get-Date
Write-Host "Script started at $StartDateTime" -ForegroundColor Red


# ModelName-ModelNumber
$folderName = ("$modelName-$modelNumber").Replace(' ', '-')
$pathMain = Join-Path -Path $pathShareXP -ChildPath $folderName
if (Test-Path -Path $pathMain) {
    Write-Host "Deleting the existing $pathMain folder..." -ForegroundColor Yellow
    Remove-Item -Path $pathMain -Recurse -Force
}
New-Item -Path $pathMain -ItemType Directory > $null


# Have unmodified TXTSETUP.SIF in $PSScriptRoot, copy it into $pathMain, and modify it.
# Copy TXTSETUP.SIF to the $pathMain folder.
# Assumes the HDD/SSD is plugged into SATA-0 and is the only one.
# Add two lines under [SetupData] section:
# BootPath = "\I386\"
# SetupSourceDevice = "\Device\Harddisk0\Partition1"
$pathTxtsetup = "$PSScriptRoot\TXTSETUP.SIF"
if (-not (Test-Path -Path $pathTxtsetup) ) {
    Write-Host "Cannot find TXTSETUP.SIF! Exiting!"
    exit 1
}
Write-Host "Copying $pathTxtsetup to $pathMain" -ForegroundColor DarkGreen
Copy-Item -Path $pathTxtsetup -Destination $pathMain

$tempText = @"

BootPath = "\I386\"
SetupSourceDevice = "\Device\Harddisk${diskNumber}\Partition1"
"@
$pathTxtsetup = "$pathMain\TXTSETUP.SIF"
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


# Drivers MUST BE IN SUBFOLDERS UNDER $OEM$\$1\DRIVERS
# https://msfn.org/board/topic/19792-textmode-massstoragedrivers-method/
# RAID/SATA DRIVERS MUST BE UNDER:
#   $OEM$
#   $OEM$\TEXTMODE
#   I386\$OEM$
#   I386\$OEM$\TEXTMODE
#
# CODE BELOW IS SPECIFIC TO THE FOLDER CREATED WHEN EXTRACTING THE CAB FILE.
$basepathExtracteddrivers = Join-Path -Path $PSScriptRoot -ChildPath $modelNumber
$pathOem1Drivers = Join-Path -Path $pathMain -ChildPath '\$OEM$\$1\DRIVERS'
New-Item -Path $pathOem1Drivers -ItemType Directory > $null
$pathX86drivers

if ( -not([string]::IsNullOrWhiteSpace($pathDellDriverCab)) -and (Get-AuthenticodeSignature -FilePath $pathDellDriverCab).Status -eq "Valid" ) {
    # Extract the drivers
    Start-Process "expand.exe" -ArgumentList "$pathDellDriverCab -F:* $PSScriptRoot" -Wait -LoadUserProfile
    $pathX86drivers = Join-Path -Path $basepathExtracteddrivers -ChildPath 'xp\x86'
    Copy-Item -Path "$pathX86drivers\*" -Destination $pathOem1Drivers -Recurse -Force
}

if ( -not([string]::IsNullOrWhiteSpace($pathDriversMisc)) ) {
    # Add other drivers
    if ( (Test-Path -Path $pathDriversMisc) -and ((Get-ChildItem -Path $pathDriversMisc).Count -gt 0) ) {
        Copy-Item -Path "$pathDriversMisc\*" -Destination $pathOem1Drivers -Recurse -Force
    }
}

$oemBootFiles = ""
$massStorageDrivers = ""
if ($useAhci) {
    $pathTxtSetupOem = ""
    if ( -not([string]::IsNullOrWhiteSpace($storageReleaseId)) ) {
        # Inject AHCI drivers from Dell source
        $pathTxtSetupOem = ((Get-ChildItem "TXTSETUP.OEM" -Path $pathOem1Drivers -Recurse) | Where-Object {$_.FullName -like "*$storageReleaseId*"})
    }
    else {
        # Inject AHCI drivers from NON-Dell source
        # Store in path defined by $pathDriversMisc
        $pathTxtSetupOem = ((Get-ChildItem "TXTSETUP.OEM" -Path $pathOem1Drivers -Recurse))
    }

    $pathStoragedrivers = $pathTxtSetupOem.DirectoryName
    Copy-Item -Path "$pathStoragedrivers" -Destination "$pathMain\`$OEM$\TEXTMODE" -Recurse -Force
    Copy-Item -Path "$pathStoragedrivers" -Destination "$pathMain\I386\`$OEM$" -Recurse -Force
    Copy-Item -Path "$pathStoragedrivers" -Destination "$pathMain\I386\`$OEM$\TEXTMODE" -Recurse -Force

    $temp1 = Select-String -Path $pathTxtSetupOem.FullName -Pattern '\b(SATA|AHCI|RAID)\b'
    foreach ($line in $temp1){
        $tempArray = $line -split "="
        $tempArray = $tempArray.Trim()
        $massStorageDrivers += $tempArray[1] + ' = "OEM"' + [Environment]::NewLine
    }
        
    $temp = Get-ChildItem -Path "$pathStoragedrivers" -Include "*.inf", "*.cat", "*.sys", "TXTSETUP.OEM" -Name
    foreach ($line in $temp)
    {
        $oemBootFiles += ($line + [Environment]::NewLine)
    }
}

if (Test-Path -Path $basepathExtracteddrivers) {
    Remove-Item -Path $basepathExtracteddrivers -Recurse -Force
}


Set-Location "$pathMain\`$OEM$\`$1"  # Makes it easier when resolving relative paths.
$oemDriverspath = ""
if ((Get-ChildItem * -Recurse -Include "*.inf").Count -gt 0) {
    $tempObj = (Get-ChildItem * -Recurse -Include "*.inf") | Select-Object Directory -Unique
    $oemDriverspath = 'OemPnPDriversPath="'
    foreach ($the_folder in $tempObj){
        if ($null -ne $the_folder.Directory) {
            # Write-Host ($the_folder.Directory | Resolve-Path -Relative)  # Leave in code. Uncomment for debugging!
            $temp = ($the_folder.Directory | Resolve-Path -Relative)
            $temp = $temp.Substring(2)
            $oemDriverspath += "$temp;"
        } 
    }
    $oemDriverspath =  $oemDriverspath.Remove($oemDriverspath.Length - 1, 1)  # Remove the last semicolon
    $oemDriverspath = $oemDriverspath + '"'
}

Set-Location $PSScriptRoot


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

[GuiRunOnce]
"w32tm /register"
"w32tm /config /manualpeerlist:10.10.10.2 /syncfromflags:manual /update"
"cmd.exe /c del /q %SYSTEMDRIVE%\TXTSETUP.SIF"
"cmd.exe /c rd /s /q %SYSTEMDRIVE%\`$OEM$"
"cmd.exe /c rd /s /q %SYSTEMDRIVE%\I386"
"cmd.exe /c %SYSTEMDRIVE%\install-software.bat"


;The [OEMBootFiles] section contains entries for specifying OEM-supplied boot files. This section is valid only if you use
;the entry OemPreinstall = Yes in the [Unattend] section and you place the files listed here in the \`$OEM$\Textmode folder;
;of the distribution share.
;https://learn.microsoft.com/en-us/previous-versions/orphan-topics/ws.10/cc755793(v=ws.10)?redirectedfrom=MSDN
;
[OEMBootFiles]
$oemBootFiles

; THIS IS SPECIFIC TO THE DELL OPTIPLEX 9010! MODIFY FOR DIFFERENT DELL SYSTEMS!
[MassStorageDrivers]
$massStorageDrivers
"@
Write-Host "Creating $pathMain\winnt.sif" -ForegroundColor DarkGreen
if ( -not (Test-Path -Path "$pathMain\I386") ) {
    New-Item -Path "$pathMain\I386" -ItemType Directory > $null
}
Out-File -Encoding ascii -InputObject $winntSIF -FilePath "$pathMain\I386\winnt.sif"


# $shareLetter = "Y"
$pathTemp = $shareLetter + ':\' + $folderName

# Create batch file that partitions the disk, copies the files, and runs bootsect.
$theScript = @"
@echo off

rem Running diskpart...
diskpart /s X:\diskpart-script.txt

rem Copying files...
robocopy "${shareLetter}:\I386" "${diskLetter}:\I386" /e
robocopy "${pathTemp}\I386" "${diskLetter}:\I386" /e
robocopy "${pathTemp}\`$OEM$" "${diskLetter}:\`$OEM$" /e

IF EXIST "${shareLetter}:\SOFTWARE\" (xcopy "${shareLetter}:\SOFTWARE\*" "${diskLetter}:\" /e)

copy "${shareLetter}:\I386\NTDETECT.COM" "${diskLetter}:\NTDETECT.COM"
copy "${shareLetter}:\I386\SETUPLDR.BIN" "${diskLetter}:\NTLDR"
copy "${pathTemp}\TXTSETUP.SIF" "${diskLetter}:\TXTSETUP.SIF"

bootsect /nt52 ${diskLetter}: /mbr /force

net use ${shareLetter}: /delete

wpeutil reboot

"@
Write-Host "Creating install-windows-xp-$folderName.bat in $pathShareScripts" -ForegroundColor DarkGreen
Out-File -Encoding ascii -InputObject $theScript -FilePath "$pathShareScripts\install-windows-xp-$folderName.bat"


Write-Host "Script completed at $(Get-Date) and took $( (New-TimeSpan -Start $StartDateTime).Hours ) hours, $( (New-TimeSpan -Start $StartDateTime).Minutes ) minutes, $( (New-TimeSpan -Start $StartDateTime).Seconds ) seconds" -ForegroundColor Red
