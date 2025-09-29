#Requires -RunAsAdministrator
#Requires -Version 5.1

$StartDateTime = Get-Date
Write-Host "Script started at $StartDateTime" -ForegroundColor Red

# Variables
$sectionSetupData = @"

BootPath = "\I386\"
SetupSourceDevice = "\Device\Harddisk0\Partition1"
"@

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

;Specifies whether the user must accept the End-User License Agreement (EULA) included with Windows.
OemSkipEula = Yes

;Determines the installation folder in which you install Windows.
TargetPath=\WINDOWS

;Specifies whether Setup skips Windows Welcome or Mini-Setup when preinstalling Windows XP Home Edition or Windows XP Professional by using the CD Boot method.
;UnattendSwitch = Yes | No
UnattendSwitch = Yes

[GuiUnattended]
;Set AdminPassword to something or setup will stop the process and ask for one.
AdminPassword = "password123"
;Enables Setup to install encrypted passwords for the Administrator account.
;EncryptedAdminPassword = Yes | No
EncryptedAdminPassword = No

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
ComputerName=*

[RegionalSettings]
LanguageGroup=1
SystemLocale=00000409
UserLocale=00000409
InputLocale=0409:00000409

[Identification]
JoinWorkgroup=WORKGROUP

[Networking]
InstallDefaultComponents=Yes

[GuiRunOnce]
"%SYSTEMDRIVE%\Hyper-V-IS\setup.exe /quiet"
"@


# Paths
$pathXPUpdateFolder = "$PSScriptRoot\Post-SP3-Updates"
$pathXPUpdateList = "$PSScriptRoot\post-sp3-updates-list.txt"
$pathVHD = "$PSScriptRoot\xp-install.vhdx"
$pathXPiso = "$PSScriptRoot\en_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73974.iso"

# No point of continuing if the ISO is not present.
if ( !(Test-Path -Path $pathXPiso) ) {
    Write-Host "Windows XP ISO file not present! Exiting!"
    Exit
}


# Mount ISO file
Write-Host "Mounting the ISO file." -ForegroundColor DarkGreen
$theDriveLetter = (Mount-DiskImage -StorageType ISO -ImagePath $pathXPiso -ErrorAction Stop -PassThru | Get-Volume).DriveLetter
$pathISOi386 = "${theDriveLetter}:\I386"

$params = @{
    Path = "$pathVHD"
    SizeBytes = 50GB
    Dynamic = $true
}
New-VHD @params
$theVHD = Mount-VHD -Path $pathVHD -Passthru | Initialize-Disk -PartitionStyle MBR -Passthru #Passthru required
try {
    New-Partition -DiskNumber $theVHD.DiskNumber -UseMaximumSize -DriveLetter W -IsActive | Format-Volume -FileSystem NTFS -NewFileSystemLabel "WindowsXP" -Confirm:$false -Force

    $vhdDriveLetter = (Get-Volume -FileSystemLabel WindowsXP).DriveLetter

    Start-Process -FilePath "bootsect.exe" -Wait -ArgumentList "/nt52 ${vhdDriveLetter}: /mbr /force" -NoNewWindow

    Copy-Item -Path "$pathISOi386" -Destination "${vhdDriveLetter}:\I386" -Recurse -Force

    Copy-Item -Path "$pathISOi386\SETUPLDR.BIN" -Destination "${vhdDriveLetter}:\NTLDR"
    Copy-Item -Path "$pathISOi386\NTDETECT.COM" -Destination "${vhdDriveLetter}:\"
    Copy-Item -Path "$pathISOi386\TXTSETUP.SIF" -Destination "${vhdDriveLetter}:\"
    Copy-Item -Path "$PSScriptRoot\Hyper-V-IS\" -Destination "${vhdDriveLetter}:\Hyper-V-IS\" -Recurse -Force

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
                Start-Process "$theUpdate" -ArgumentList "/integrate:${vhdDriveLetter}:\ /passive /norestart" -Wait -LoadUserProfile -NoNewWindow
            }
            else {
                Write-Host "$line does not exists!" -ForegroundColor Yellow
            }
        }
        Write-Host "Slipstreaming Windows XP updates...completed" -ForegroundColor DarkMagenta
    }


    # Add two lines under [SetupData] section:
    # BootPath = "\I386\"
    # SetupSourceDevice = "\Device\Harddisk0\Partition1"
    $pathTxtsetup = "${vhdDriveLetter}:\TXTSETUP.SIF"
    if ( Select-String -Path $pathTxtsetup -Pattern '\[SetupData\]' -Quiet ) {
        $tempObject = Select-String -Path $pathTxtsetup -Pattern '\[SetupData\]'
        if ( !($tempObject -is [array]) ) {
            Write-Host "Adding BootPath and SetupSourceDevice to TXTSETUP.SIF" -ForegroundColor DarkGreen
            Set-ItemProperty -Path "$pathTxtsetup" -Name IsReadOnly -Value $false
            $fileContent = Get-Content -Path "$pathTxtsetup"
            $fileContent[$tempObject.LineNumber - 1] += $sectionSetupData
            $fileContent | Set-Content -Path "$pathTxtsetup"
            Set-ItemProperty -Path "$pathTxtsetup" -Name IsReadOnly -Value $true
        }
        else {
            Write-Host "Multiple [SetupData] matches found!" -ForegroundColor Yellow
            Write-Host "This should not happen!" -ForegroundColor Yellow
        }
    }

    Write-Host "Creating ${vhdDriveLetter}:\I386\winnt.sif" -ForegroundColor DarkGreen
    Out-File -Encoding ascii -InputObject $winntSIF -FilePath "${vhdDriveLetter}:\I386\winnt.sif"
}
finally {
    Dismount-VHD -DiskNumber $theVHD.DiskNumber
}

# Unmount the ISO.
 Write-Host "Unmounting the ISO image." -ForegroundColor DarkGreen
 Dismount-DiskImage -ImagePath $pathXPiso -ErrorAction Stop | Out-Null
