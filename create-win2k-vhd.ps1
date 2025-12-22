# SCRIPT PROVIDED AS IS SO RTFM and FIGURE IT OUT YOURSELF IF YOU RUN INTO ISSUES!
#
# Quick and dirty script that creates a Windows 2000 SP4 Professional VHDX.
# Assumes vmguest.iso and the Windows 2000 SP4 ISO are in the same location as this script.
# Hyper-V IS automatically installed if vmguest.iso is present.
# Tested on Windows 11 Hyper-V. IDGAF THAT THIS IS NOT OFFICALLY SUPPORTED!

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
TargetPath=\WINNT


[GuiUnattended]
;Set AdminPassword to something or setup will stop the process and ask for one.
AdminPassword = "password123"

AutoLogon=Yes
AutoLogonCount=1

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
;Specifies the Microsoft Product Identification (Product ID) number.
;Not needed if last 3 digits of Pid value is 270 in SETUPP.INI
;ProductID=""

FullName = "Admin"
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
;Script will uncomment line below if vmguest.iso is present.
;"%SYSTEMDRIVE%\Hyper-V-IS\setup.exe /quiet"
"@


# Paths
$pathVHD = "$PSScriptRoot\win2k.vhdx"
$pathXPiso = "$PSScriptRoot\Windows_2000_SP4.iso"
$pathVMguestiso = "$PSScriptRoot\vmguest.iso"


# No point of continuing if the ISO is not present.
if ( !(Test-Path -Path $pathXPiso) ) {
    Write-Host "Windows 2000 SP4 ISO file not present! Exiting!" -ForegroundColor Red
    Exit
}

# Check if vmguest.iso exists. If so, then calculate its hash.
# vmguest.iso is extracted from Hyper-V Server 2008 R2 SP1
# Download link below:
# https://www.microsoft.com/en-us/download/details.aspx?id=20196
#
# Hyper-V_Server_R2_SP1_MultiLang.iso
# MD5 = 1E1ED8A9329D13549ABC41E8F4488413
# SHA1 = 8A60D8E80D5D969774C31E5F49CF42E7774C46F3
# SHA256 = 5D37E8189538A2430326F19F26202D4FA835696DCD675CE0DCFEA34A1E938FF6
$existVMguestiso = $false
if ( Test-Path -Path $pathVMguestiso ) {
    Write-Host "Calculating SHA256 of vmguest.iso" -ForegroundColor DarkGreen
    
    $hashFile = Get-FileHash -Algorithm SHA256 -Path "$pathVMguestiso"
    Write-Host "Calculated SHA256 =" $hashFile.Hash
    if ($hashFile.Hash -eq "B1149A26ACC85BD3244A49E1648827E18F2DBE6AE264DC2713A1978D4BCAA9B2") {
        Write-Host "vmguest.iso SHA256 is valid!" -ForegroundColor DarkGreen
        $existVMguestiso = $true
    }
    else {
        Write-Host "vmguest.iso SHA256 not equal to B1149A26ACC85BD3244A49E1648827E18F2DBE6AE264DC2713A1978D4BCAA9B2" -ForegroundColor Red
    }
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
    $fileSystemLabel = "Windows2000"
    New-Partition -DiskNumber $theVHD.DiskNumber -UseMaximumSize -DriveLetter W -IsActive | Format-Volume -FileSystem NTFS -NewFileSystemLabel "$fileSystemLabel" -Confirm:$false -Force

    $vhdDriveLetter = (Get-Volume -FileSystemLabel "$fileSystemLabel").DriveLetter

    Start-Process -FilePath "bootsect.exe" -Wait -ArgumentList "/nt52 ${vhdDriveLetter}: /mbr /force" -NoNewWindow

    Copy-Item -Path "$pathISOi386" -Destination "${vhdDriveLetter}:\I386" -Recurse -Force

    Copy-Item -Path "$pathISOi386\SETUPLDR.BIN" -Destination "${vhdDriveLetter}:\NTLDR"
    Copy-Item -Path "$pathISOi386\NTDETECT.COM" -Destination "${vhdDriveLetter}:\"
    Copy-Item -Path "$pathISOi386\TXTSETUP.SIF" -Destination "${vhdDriveLetter}:\"

    if ($existVMguestiso) {
        # Create the Hyper-V-IS folder
        $pathHyperVis = "${vhdDriveLetter}:\Hyper-V-IS"
        New-Item -Path "$pathHyperVis" -ItemType Directory | Out-Null

        # Mount vmguest.iso and copy files to the Hyper-V-IS folder.
        $tempDriveLetter = (Mount-DiskImage -StorageType ISO -ImagePath "$pathVMguestiso" -ErrorAction Stop -PassThru | Get-Volume).DriveLetter
        $pathTemp = "${tempDriveLetter}:\support\x86"
        $listFiles = @("kmdf.inf", "setup.exe", "WdfCoInstaller01007.dll", "Windows5.x-HyperVIntegrationServices-x86.msi", 
                        "Windows6.0-HyperVIntegrationServices-x86.cab", "Windows6.1-HyperVIntegrationServices-x86.cab")
        foreach ($file in $listFiles) {
            Copy-Item -Path "$pathTemp\$file" -Destination "$pathHyperVis\"
        }
        Dismount-DiskImage -ImagePath "$pathVMguestiso" -ErrorAction Stop | Out-Null

        # Hyper-V IS will install for the first and only autologon.
        $winntSIF = $winntSIF.Replace(";`"%SYSTEMDRIVE%\Hyper-V-IS\setup.exe /quiet`"", "`"%SYSTEMDRIVE%\Hyper-V-IS\setup.exe /quiet`"")
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

    # Code below modifies SETUPP.INI so no key is needed.
    # https://petri.com/install_windows_2000_without_supplying_the_cd_key/
    $pathSetuppini = "${vhdDriveLetter}:\I386\SETUPP.INI"
    if ( Select-String -Path $pathSetuppini -Pattern 'Pid=' -Quiet ) {
        Write-Host "Modifying SETUPP.INI" -ForegroundColor DarkGreen

        Set-ItemProperty -Path "$pathSetuppini" -Name IsReadOnly -Value $false
        $tempObject = Select-String -Path $pathSetuppini -Pattern 'Pid='
        
        $fileContent = Get-Content -Path "$pathSetuppini"
        $fileContent[$tempObject.LineNumber - 1] = $tempObject.Line -replace '.{3}$', '270'
        $fileContent | Set-Content -Path "$pathSetuppini"
        
        Set-ItemProperty -Path "$pathSetuppini" -Name IsReadOnly -Value $true
    }
}
finally {
    Dismount-VHD -DiskNumber $theVHD.DiskNumber
}

# Unmount the ISO.
 Write-Host "Unmounting the ISO image." -ForegroundColor DarkGreen
 Dismount-DiskImage -ImagePath $pathXPiso -ErrorAction Stop | Out-Null