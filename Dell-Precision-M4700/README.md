# Dell Precision M4700

## Specifications
+ Intel Core **i7-3630QM**
+ 16 GB DDR3 RAM
+ ~256~ 500 GB Samsung 870 EVO SSD
+ Intel HD Graphics 4000
+ Nvidia Quadro K1000M
+ Intel 82579LM gigabit ethernet
+ Intel Centrino Ultimate-N 6300 802.11n 3x3 Half Mini-card
+ Dell Wireless 380 Bluetooth 4.0 LE Module
+ Dell ControlVault firmware version **3.4.10.0**
+ BIOS version **A19**

## Dell Support Links
+ [Overview](https://www.dell.com/support/product-details/en-us/product/precision-m4700/overview)
+ [Drivers](https://www.dell.com/support/product-details/en-us/product/precision-m4700/drivers)
+ [WinXP Driver Cab (32 and 64-bit) - M4700-xp-A07-YH4YP.CAB](https://dl.dell.com/FOLDER02141120M/1/M4700-xp-A07-YH4YP.CAB)
+ [Dell WinPE Driver CAB Pack - Dell-WinPE-Drivers-A01.CAB](https://dl.dell.com/FOLDER01464536M/1/Dell-WinPE-Drivers-A01.CAB)
+ [Intel Rapid Storage Technology F6 Driver](https://www.dell.com/support/home/en-us/drivers/driversdetails?driverId=H79NK)
+ [Dell Command Deploy Precision M4700 Windows 10 Driver Pack - M4700-win10-A02-GMFJV.CAB](https://dl.dell.com/FOLDER03650061M/1/M4700-win10-A02-GMFJV.CAB)

## Notes for create-winpe-xp.ps1
+ Making a USB flash drive bootable and copying contents of the Windows XP ISO image will result in **headaches and misery**. I failed to heed the warnings of a MSFN post and wasted a lot of time troubleshooting.
+ A better way is to create a bootable Windows PE USB drive using Windows ADK and PE add-on.
  + I386 folder is copied to the mount folder.
  + Intel storage drivers are integrated so textmode setup proceeds smoothly.
  + PNP drivers are installed during setup so no yellow exclamation marks in **Device Manager**.
  + prep-install.bat will run after Windows PE loads (make sure there's enough RAM).
    + Diskpart runs.
    + Copy files and folders over.
    + Reboot and setup runs.
  + Edit `$winntSIF` in the script to suit your needs.
  + Script provided **AS IS. READ THE COMMENTS! I AM NOT RESPONSIBLE FOR ANY DATA LOSS!**
  + See below for directory structure (some parts removed for brevity):
```
Folder PATH listing
C:\USERS\USER\DESKTOP\M4700-PE-XP-USB
|   create-winpe-xp.ps1
|   en_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73974.iso
|   M4700-xp-A07-YH4YP.CAB
|   
+---CUs
|       windows11.0-kb5043080-x64_953449672073f8fb99badb4cc6d5d7849b9c83e8.msu
|       windows11.0-kb5065426-x64_32b5f85e0f4f08e5d6eabec6586014a02d3b6224.msu
|       
\---WinPE_amd64
    +---bootbins
    |       
    +---media
    |           
    \---mount
```
