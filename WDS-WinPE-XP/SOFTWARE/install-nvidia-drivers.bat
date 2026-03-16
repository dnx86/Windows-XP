SETLOCAL EnableDelayedExpansion

SET PATH_7z="%ProgramFiles%\7-Zip\7z.exe"
SET PATH_NvidiaDriversZip="%SYSTEMDRIVE%\NVIDIA-XP-368_81.zip"
SET PATH_NvidiaSetupExe="%SYSTEMDRIVE%\NVIDIA\DisplayDriver\368.81\WinXP\International\setup.exe"

IF EXIST %PATH_7z% IF EXIST %PATH_NvidiaDriversZip% (
    start "" /wait !PATH_7z! x !PATH_NvidiaDriversZip! -o"%SYSTEMDRIVE%"
    start "" /wait !PATH_NvidiaSetupExe! -noeula -clean -n
    start "" /wait /b del /q %PATH_NvidiaDriversZip%
)

(goto) 2>nul & del /f /q "%~f0"