# Dell OptiPlex 9010

## Specifications
+ Intel Core **i7-3770**
+ 8 GB DDR3 RAM
+ 120 GB Intel SSDSC2BB120G7R
+ Intel HD Graphics 4000
+ AMD Radeon HD 7570
+ Intel 82579LM gigabit ethernet
+ BIOS version **A30**

## Dell Support Links
+ [Overview](https://www.dell.com/support/product-details/en-us/product/optiplex-9010/overview)
+ [Drivers](https://www.dell.com/support/product-details/en-us/product/optiplex-9010/drivers)
+ [WinXP Driver Cab (32 and 64-bit) - 9010-xp-A05-8YR57.CAB](https://dl.dell.com/FOLDER02061609M/1/9010-xp-A05-8YR57.CAB)
```
File Name:
9010-xp-A05-8YR57.CAB

File Size:
201.37 MB

MD5:
7b911a4a767903a8e6f8057e26037bb5

SHA1:
022e872ae4af5edb0d5b0d3116b50000cea0077b

SHA-256:
f3642f94cf1bd46bd7341e1cee6d71492149214f8a11f5b801128a212ad87e35
```

## Notes for create-winpe-xp-9010.ps1
+ **YES I AM AWARE OF TOOLS LIKE RUFUS BUT I PREFER TO DO THINGS THE HARD WAY!**
+ **You won't see me using Snappy Driver Installer. Only official drivers from Dell are used.**
+ **I have WSUS running on Windows Server 2022 so that's how I am updating my Windows XP installation.**
```
- Configure the "Specify Intranet Microsoft Update Service Location" GPO.
- Run Windows Update until there's no other updates left.
- Get Windows Embedded POSReady 2009 updates with the command below:
  REG ADD HKLM\SYSTEM\WPA\POSReady /v Installed /d 1 /t REG_DWORD /f
- Run Windows Update again. There should be 17 updates that fail to install.
```
+ My way is to create a bootable Windows PE USB drive using Windows ADK and PE add-on.
  + I386 folder is copied to the mount folder.
  + Intel storage drivers are integrated so textmode setup proceeds smoothly.
  + PNP drivers are installed during setup so no yellow exclamation marks in **Device Manager**.
  + prep-install.bat will run after Windows PE loads (make sure there's enough RAM).
    + Diskpart runs.
    + Copy files and folders over.
    + Reboot and setup runs.
  + Edit `$winntSIF` in the script to suit your needs.
  + Script provided **AS IS. READ THE COMMENTS! I AM NOT RESPONSIBLE FOR ANY DATA LOSS!**
