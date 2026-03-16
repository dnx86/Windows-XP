ECHO multi(0)disk(0)rdisk(0)partition(1)\WINDOWS="VGA only" /basevideo /fastdetect>>%SYSTEMDRIVE%\boot.ini

w32tm /config /manualpeerlist:"10.10.10.2" /syncfromflags:manual /update

IF EXIST %SYSTEMDRIVE%\7z2600.exe (
    start "" /wait %SYSTEMDRIVE%\7z2600.exe /S

    @REM Workaround for TIMEOUT command unavailable in Windows XP SP3.
    @REM DO NOT REMOVE! File may not be deleted if there's no delay.
    start "" /wait ping -n 11 localhost>nul

    del /q %SYSTEMDRIVE%\7z2600.exe
    )
IF EXIST %SYSTEMDRIVE%\vlc-3.0.23-win32.exe (
    start "" /wait %SYSTEMDRIVE%\vlc-3.0.23-win32.exe  /L=1033 /S

    @REM Workaround for TIMEOUT command unavailable in Windows XP SP3.
    @REM DO NOT REMOVE! File may not be deleted if there's no delay.
    start "" /wait ping -n 11 localhost>nul

    del /q %SYSTEMDRIVE%\vlc-3.0.23-win32.exe
    )
IF EXIST %SYSTEMDRIVE%\windowsupdateagent30-x86.exe (
    start "" /wait %SYSTEMDRIVE%\windowsupdateagent30-x86.exe /quiet /norestart

    @REM Workaround for TIMEOUT command unavailable in Windows XP SP3.
    @REM DO NOT REMOVE! File may not be deleted if there's no delay.
    start "" /wait ping -n 11 localhost>nul

    del /q %SYSTEMDRIVE%\windowsupdateagent30-x86.exe
    )
IF EXIST %SYSTEMDRIVE%\wsus_location.reg (
    start "" /wait reg import %SYSTEMDRIVE%\wsus_location.reg

    @REM Workaround for TIMEOUT command unavailable in Windows XP SP3.
    @REM DO NOT REMOVE! File may not be deleted if there's no delay.
    start "" /wait ping -n 11 localhost>nul

    start "" /wait gpupdate /force
    del /q %SYSTEMDRIVE%\wsus_location.reg
    )
IF EXIST %SYSTEMDRIVE%\Initiator-2.08-build3825-x86fre.exe (
    start "" /wait %SYSTEMDRIVE%\Initiator-2.08-build3825-x86fre.exe /quiet /passive

    @REM Workaround for TIMEOUT command unavailable in Windows XP SP3.
    @REM DO NOT REMOVE! File may not be deleted if there's no delay.
    start "" /wait ping -n 11 localhost>nul

    del /q %SYSTEMDRIVE%\Initiator-2.08-build3825-x86fre.exe
    )

IF EXIST %SYSTEMDRIVE%\update-windows.bat (
    %SYSTEMDRIVE%\update-windows.bat
    )
