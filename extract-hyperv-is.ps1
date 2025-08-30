# Quick and dirty script to extract Hyper-V Integration Services x86 files from KB5063950.
# It assumes the MSU file is in the same directory.
# Tested in Windows Sandbox.

$msuName = "windows8.1-kb5063950-x64_d743be306a7c9840e7c41cf2355564e3fea6d7e7.msu"
$cabName = "Windows8.1-KB5063950-x64.cab"
if ( !(Test-Path -Path "$PSScriptRoot\$msuName") ) {
    Write-Host "The MSU file msut be in the same location as this script!"
    Exit
}
# expand -i "$PSScriptRoot\$msuName" -F:$cabName $PSScriptRoot
Start-Process -FilePath "expand.exe" -Wait -ArgumentList "-i `"$PSScriptRoot\$msuName`" -F:$cabName $PSScriptRoot" -NoNewWindow
# expand -i "$PSScriptRoot\$cabName" -F:windows5.x-hypervintegrationservices-x86* $PSScriptRoot
Start-Process -FilePath "expand.exe" -Wait -ArgumentList "-i `"$PSScriptRoot\$cabName`" -F:windows5.x-hypervintegrationservices-x86* $PSScriptRoot" -NoNewWindow
# expand -i "$PSScriptRoot\$cabName" -F:windows6*-hypervintegrationservices-x86* $PSScriptRoot
Start-Process -FilePath "expand.exe" -Wait -ArgumentList "-i `"$PSScriptRoot\$cabName`" -F:windows6*-hypervintegrationservices-x86* $PSScriptRoot" -NoNewWindow
# expand "$PSScriptRoot\$cabName" -F:setup.exe $PSScriptRoot
Start-Process -FilePath "expand.exe" -Wait -ArgumentList "`"$PSScriptRoot\$cabName`" -F:setup.exe $PSScriptRoot" -NoNewWindow
Copy-Item -Path "$PSScriptRoot\x86_microsoft-hyper-v-guest-installer_31bf3856ad364e35_6.3.9600.19456_none_0666f39c3d42b614\setup.exe" -Destination $PSScriptRoot

# Download and install
# Windows Driver Kit 8 redistributable components
$wdfcoinstallerName = "wdfcoinstaller.msi"
if ( !(Test-Path -Path "$PSScriptRoot\$wdfcoinstallerName") ) {
    $url = "https://go.microsoft.com/fwlink/p/?LinkID=253170"
    Start-BitsTransfer -Source $url -Destination "$PSScriptRoot\$wdfcoinstallerName"
}
# Verify digital signature
if ((Get-AuthenticodeSignature "$PSScriptRoot\$wdfcoinstallerName").Status -ne "Valid") {
    Write-Host "Error - Invalid or no signature"
    Exit
}

Write-Host "Installing Windows Driver Kit 8 redistributable components..."
Start-Process -FilePath "msiexec.exe" -Wait -ArgumentList "/i `"$PSScriptRoot\$wdfcoinstallerName`" /quiet /passive" -NoNewWindow

$WDK8InstallLocation = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\8.0\redist\wdf\x86")
Copy-Item -Path "$WDK8InstallLocation\WdfCoInstaller01009.dll" -Destination $PSScriptRoot

# Create kmdf.ini
$kmdfContents = @"
[Version]
Signature="`$WINDOWS NT$"

[WdfSection]
KmdfService = dummy, dummy_wdfsect

[dummy_wdfsect]
KmdfLibraryVersion = 1.5
"@
$kmdfContents | Out-File -FilePath "$PSScriptRoot\kmdf.inf" -Encoding ascii

# Clean up
Write-Host "Cleaning up..."
Remove-Item -Path "$PSScriptRoot\$cabName" -Force
Remove-Item -Path "$PSScriptRoot\amd64_microsoft*" -Recurse -Force
Remove-Item -Path "$PSScriptRoot\x86_microsoft*" -Recurse -Force

Write-Host "Uninstalling Windows Driver Kit 8 redistributable components..."
Start-Process -FilePath "msiexec.exe" -Wait -ArgumentList "/x `"$PSScriptRoot\$wdfcoinstallerName`" /quiet" -NoNewWindow
# Remove-Item -Path "$PSScriptRoot\$wdfcoinstallerName" -Force