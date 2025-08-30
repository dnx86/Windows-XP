# Hyper-V Integration Services for Windows XP (x86)

## Purpose
To run Windows XP (x86) as a guest OS in Hyper-V on Windows Server 2025 (yes I am aware that it is **not a supported guest OS**[^1]).

## Method 1 - Acquire vmguest.iso
This involves downloading the Hyper-V Server 2012 R2 ISO and extracting vmguest.iso from it[^2],[^3].

## Method 2 - Extract the files from Windows Server 2012 R2 Monthly Rollup
- Go to the Windows 8.1 and Windows Server 2012 R2 update history and download the latest monthly rollup[^4].
- At the time of writing this, August 12, 2025 - KB5063950 (Monthly Rollup)[^5]. The Hyper-V Integration Services build number is **6.3.9600.19456**.
- **extract-hyperv-is.ps1** is a simple Powershell script I wrote that simplifies the process of acquiring the integration services setup files.
After it is done running, transfer the files to the Windows XP guest OS, run setup.exe, and reboot.

## Notes
Other build numbers and KBs you can extract from.
- 6.3.9600.17831, KB3063283[^6], windows8.1-kb3063283-x64_24362234dbc7f5795cd3563061332650c1b8c42f.msu
- 6.3.9600.18398, KB3172614[^7], Windows8.1-KB3172614-x64.msu
- 6.3.9600.18692, KB4022720[^8], windows8.1-kb4022720-x86_9f326e97917606005b866deea24d9b9135cc1fae.msu

## Links/References
[^1]: [Supported Windows guest operating systems for Hyper-V on Windows, Windows Server, and Azure Local](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/supported-windows-guest-operating-systems-for-hyper-v-on-windows)
[^2]: [Hyper-V VMGuest.iso for older Windows OSes in Win10/2016](https://smudj.wordpress.com/hyper-v-vmguest-iso-for-older-windows-oses-in-win10-2016/)
[^3]: [Hyper-V 2016 Windows XP Virtual Machine Integration Services](https://timothygruber.com/hyper-v-2/hyper-v-2016-windows-xp-virtual-machine-integration-services/)
[^4]: [Windows 8.1 and Windows Server 2012 R2 update history](https://support.microsoft.com/en-us/topic/windows-8-1-and-windows-server-2012-r2-update-history-47d81dd2-6804-b6ae-4112-20089467c7a6)
[^5]: [August 12, 2025 - KB5063950 (Monthly Rollup)](https://support.microsoft.com/en-us/help/5063950)
[^6]: [Update to improve the backup of Hyper-V Integrated components in Hyper-V Server 2012 R2](https://support.microsoft.com/en-us/kb/3063283)
[^7]: [July 2016 update rollup for Windows 8.1 and Windows Server 2012 R2](https://support.microsoft.com/en-us/kb/3172614)
[^8]: [June 27, 2017—KB4022720 (Preview of Monthly Rollup)](https://support.microsoft.com/help/4022720)
