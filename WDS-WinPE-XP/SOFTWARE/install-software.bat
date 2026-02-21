IF EXIST %SYSTEMDRIVE%\7z2501.exe (%SYSTEMDRIVE%\7z2501.exe /S)
IF EXIST %SYSTEMDRIVE%\vlc-3.0.23-win32.exe (%SYSTEMDRIVE%\vlc-3.0.23-win32.exe  /L=1033 /S)
IF EXIST %SYSTEMDRIVE%\windowsupdateagent30-x86.exe (%SYSTEMDRIVE%\windowsupdateagent30-x86.exe /quiet /norestart)
IF EXIST %SYSTEMDRIVE%\wsus_location.reg (reg import %SYSTEMDRIVE%\wsus_location.reg)

ECHO multi(0)disk(0)rdisk(0)partition(1)\WINDOWS="VGA only" /basevideo /fastdetect>> %SYSTEMDRIVE%\boot.ini

IF EXIST %SYSTEMDRIVE%\7z2501.exe (del /q %SYSTEMDRIVE%\7z2501.exe)
IF EXIST %SYSTEMDRIVE%\vlc-3.0.23-win32.exe (del /q %SYSTEMDRIVE%\vlc-3.0.23-win32.exe)
IF EXIST %SYSTEMDRIVE%\windowsupdateagent30-x86.exe (del /q %SYSTEMDRIVE%\windowsupdateagent30-x86.exe)
IF EXIST %SYSTEMDRIVE%\wsus_location.reg (del /q %SYSTEMDRIVE%\wsus_location.reg)
