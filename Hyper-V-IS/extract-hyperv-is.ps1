# Quick and dirty script to extract Hyper-V Integration Services x86 files from Windows Server 2012 R2 Monthly Rollups.
# It assumes the MSU file is in the same directory.
# Tested in Windows Sandbox.
# Monthly Rollups at
# https://support.microsoft.com/en-us/help/4009470

$msuName = Get-ChildItem -Name -Filter "Windows8.1-KB*-x64*.msu"
if ( !(Test-Path -Path "$PSScriptRoot\$msuName") -or ($null -eq $msuName) ) {
    Write-Host "The MSU file must be in the same location as this script!" -ForegroundColor Red
    Exit
}

$msuName -match "-(.*)-"
$cabName = "Windows8.1-" + $Matches[1] + "-x64.cab"
if ( !(Test-Path -Path "$PSScriptRoot\$cabName") ) {
    Write-Host "Extracting $cabName from $msuName" -ForegroundColor DarkCyan
    Start-Process -FilePath "expand.exe" -Wait -ArgumentList "-i `"$PSScriptRoot\$msuName`" -F:$cabName $PSScriptRoot" -NoNewWindow
}

# Check if Hyper-V integration Services files are present in the cab file.
$tempFile = [System.IO.Path]::GetTempFileName()
Start-Process -FilePath "expand.exe" -Wait -ArgumentList "-D `"$PSScriptRoot\$cabName`" -F:*hypervintegrationservices*" -NoNewWindow -RedirectStandardOutput $tempFile
$outputTemp = Get-Content $tempFile | Out-String
Remove-Item -Path "$tempFile" -Force
if ( !($outputTemp -match "hypervintegrationservices") ) {
    Write-Host "Hyper-V integration services files not present!" -ForegroundColor Red
}

Start-Process -FilePath "expand.exe" -Wait -ArgumentList "-i `"$PSScriptRoot\$cabName`" -F:windows5.x-hypervintegrationservices-x86* $PSScriptRoot" -NoNewWindow
Start-Process -FilePath "expand.exe" -Wait -ArgumentList "-i `"$PSScriptRoot\$cabName`" -F:windows6*-hypervintegrationservices-x86* $PSScriptRoot" -NoNewWindow
Start-Process -FilePath "expand.exe" -Wait -ArgumentList "`"$PSScriptRoot\$cabName`" -F:setup.exe $PSScriptRoot" -NoNewWindow
Copy-Item -Path "$PSScriptRoot\x86_microsoft-hyper-v-guest-installer_31bf3856ad364e35_6.3.9600.19456_none_0666f39c3d42b614\setup.exe" -Destination $PSScriptRoot

# Check if Windows Driver Kit 8 redistributable components is already installed.
$isInstalled = Get-Package -ProviderName msi -Name "Windows Driver Frameworks Update Packages" -ErrorAction SilentlyContinue
if ($null -eq $isInstalled){
    Write-Host "Windows Driver Kit 8 redistributable components not installed!" -ForegroundColor Red
    # Download and install
    # Windows Driver Kit 8 redistributable components
    $wdfcoinstallerName = "wdfcoinstaller.msi"
    if ( !(Test-Path -Path "$PSScriptRoot\$wdfcoinstallerName") ) {
        Write-Host "Downloading Windows Driver Kit 8 redistributable components..." -ForegroundColor DarkCyan
        $url = "https://go.microsoft.com/fwlink/p/?LinkID=253170"
        Start-BitsTransfer -Source $url -Destination "$PSScriptRoot\$wdfcoinstallerName"
    }
    # Verify digital signature
    if ((Get-AuthenticodeSignature "$PSScriptRoot\$wdfcoinstallerName").Status -ne "Valid") {
        Write-Host "Error - Invalid or no signature" -ForegroundColor Red
        Exit
    }

    Write-Host "Installing Windows Driver Kit 8 redistributable components..." -ForegroundColor DarkCyan
    Start-Process -FilePath "msiexec.exe" -Wait -ArgumentList "/i `"$PSScriptRoot\$wdfcoinstallerName`" /quiet /passive" -NoNewWindow
}
else {
    Write-Host "Windows Driver Kit 8 redistributable components already installed!" -ForegroundColor DarkGreen
}

if ( !(Test-Path -Path "$PSScriptRoot\WdfCoInstaller01009.dll") ) {
    $WDK8InstallLocation = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\8.0\redist\wdf\x86")
    Copy-Item -Path "$WDK8InstallLocation\WdfCoInstaller01009.dll" -Destination $PSScriptRoot
}

# Create kmdf.ini
$kmdfContents = @"
[Version]
Signature="`$WINDOWS NT$"

[WdfSection]
KmdfService = dummy, dummy_wdfsect

[dummy_wdfsect]
KmdfLibraryVersion = 1.5
"@
if ( !(Test-Path -Path "$PSScriptRoot\kmdf.inf") ) {
    $kmdfContents | Out-File -FilePath "$PSScriptRoot\kmdf.inf" -Encoding ascii
}


# Clean up
Write-Host "Cleaning up..." -ForegroundColor DarkCyan
Remove-Item -Path "$PSScriptRoot\$cabName" -Force
Remove-Item -Path "$PSScriptRoot\amd64_microsoft*" -Recurse -Force
Remove-Item -Path "$PSScriptRoot\x86_microsoft*" -Recurse -Force

# Write-Host "Uninstalling Windows Driver Kit 8 redistributable components..."
# Start-Process -FilePath "msiexec.exe" -Wait -ArgumentList "/x `"$PSScriptRoot\$wdfcoinstallerName`" /quiet" -NoNewWindow

if ( !(Test-Path -Path "$PSScriptRoot\$wdfcoinstallerName") ) {
    Remove-Item -Path "$PSScriptRoot\$wdfcoinstallerName" -Force
}
