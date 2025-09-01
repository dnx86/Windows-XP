# Bootable Windows XP Installation VHDX (DRAFT)

## Purpose
Because I am bored.


## Background Reading
+ [The BIOS/MBR Boot Process](https://neosmart.net/wiki/mbr-boot-process/)
+ [Windows XP Boot Components](https://neosmart.net/wiki/windows-xp-boot-process/)
+ [Dual-Boot Guides/Windows XP](https://neosmart.net/wiki/easybcd/dual-boot/windows-xp/)
+ [Troubleshooting Windows XP Boot Problems](https://neosmart.net/wiki/xp-boot-problems/)
+ [NTLDR: Fatal error reading boot.ini: Fix for Windows XP](https://neosmart.net/wiki/ntldr-fatal-error-boot/)
+ [Rebuilding Boot.ini](https://neosmart.net/wiki/rebuilding-boot-ini-file/)

+ [Troubleshooting the Startup Process](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-xp/bb457123(v=technet.10))
+ [Reviewing and Correcting Boot.ini Settings](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-xp/bb457123(v=technet.10)#reviewing-and-correcting-bootini-settings)
+ [Q150497: How to Repair Windows NT System Files Without a CD-ROM Attached](https://jeffpar.github.io/kbarchive/kb/150/Q150497/)
+ [Supporting Installations](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-xp/bb457102(v=technet.10))
+ [Automating and Customizing Installations](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-xp/bb457100(v=technet.10))


## Requirements
+ Windows 11 or Windows Server 2025 with Hyper-V installed (this assumes your hardware meets the requirements[^1]).
+ Do yourself a favor and get `en_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73974.iso` to skip activation.
  + **You can Google the key (hint: XCYBK)!**
  + Hashes:
    ```
    MD5             5BF476E2FC445B8D06B3C2A6091FE3AA
    SHA1            66AC289AE27724C5AE17139227CBE78C01EEFE40
    SHA256          FD8C8D42C1581E8767217FE800BFC0D5649C0AD20D754C927D6C763E446D1927
    ```

## Details/Discussion
I used [^2] and [^3] as guides.

1. Create a 1 to 2 GB VHDX.
    - Initialize it with an MBR partition style.
    - Create partition 1, mark as active, and format it as FAT.
    - Use `bootsect /nt52` [^4].
2. Mount the Windows XP ISO and copy its contents to partition 1.
3. Copy `SETUPLDR.BIN, NTDETECT.COM, and TXTSETUP.SIF` from the ISO's i386 folder to partition 1.
    - Rename `SETUPLDR.BIN` to `ntldr`.
4. Edit TXTSETUP.SIF and the two lines below to the `[setupData]` section.
    ```
    BootPath = "\I386\"
    SetupSourceDevice = "\Device\Harddisk0\Partition1"
    ```
5. ***Optional*** Create partition 2, format it as FAT32 or NTFS, and copy files that you want to transfer or install (e.g. *Hyper-V Integration Services setup files*).

**More to add**

## Links/References
[^1]: [System requirements for Hyper-V on Windows and Windows Server](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/host-hardware-requirements)
[^2]: [Install XP from USB without extra tools](https://msfn.org/board/topic/151992-install-xp-from-usb-without-extra-tools/)
[^3]: [Completing a Postponed Project](https://www.losingoneself.com/blog/completing-a-postponed-project/)
[^4]: [Bootsect Command-Line Options](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/bootsect-command-line-options?view=windows-11)
