IF EXIST %SYSTEMDRIVE%\WindowsXP-KB942288-v3-x86.exe (
    WindowsXP-KB942288-v3-x86.exe /quiet
)

(goto) 2>nul & del /f /q "%~f0"