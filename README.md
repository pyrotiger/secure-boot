# Garuda Secure Boot Setup

This guide is based on a community post for Garuda Linux (Arch-based) to make it easier to find and setup Secure Boot. Arch Linux supports Secure Boot but it is disabled by default and installed with shim (generic) certificates.

> [!IMPORTANT]
> This is for a standard Garuda installation with **GRUB**.

## Instructions

To dual boot with Secure Boot enabled, follow these instructions to install Microsoft’s signed keys and sign your kernel image(s). The ‘esp’ directory should point to your system’s EFI’s folder (typically `/boot/efi` in a standard Garuda installation).

1. **UEFI Setup**: Enter UEFI and place your Secure Boot to **setup mode**. This is commonly done by clearing the installed keys in your system.

2. **Replace shim with Microsoft’s CA certificates**:
   ```bash
   sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=garuda --modules="tpm" --disable-shim-lock
   ```

3. **Install and verify sbctl**:
   ```bash
   sudo pacman -S sbctl
   sbctl status
   ```

4. **Regenerate GRUB configuration**:
   ```bash
   sudo grub-mkconfig -o /boot/grub/grub.cfg
   ```

5. **Create and Enroll Keys**:
   ```bash
   sudo sbctl create-keys
   sudo sbctl enroll-keys -m -f
   ```

6. **Verify Enrollment**:
   ```bash
   sbctl status
   ```

7. **Verify files to be signed**:
   ```bash
   sudo sbctl verify
   ```

8. **Sign unsigned files**:
   ```bash
   sudo sbctl verify | sudo sed 's/✗ /sbctl sign -s /e'
   ```

9. **Sign Linux images**:
   ```bash
   find /boot/vmlinuz-* | sudo xargs -n1 sbctl sign -s
   ```

10. **Handle Immutable Files**:
    If you get an error because of an issue with certain files being immutable:
    ```bash
    sudo chattr -i /sys/firmware/efi/efivars/<filename>
    ```
    Then re-sign afterwards.

11. **Final Verification**:
    ```bash
    sudo sbctl verify
    ```

12. **Automation (Optional/Advanced)**:
    To automate resigning of keys after a system update, you can use a pacman hook. While the original post mentioned a `systemd-boot` command, for a standard Garuda **GRUB** installation, you should sign the kernel and the grub binary.

    Example hook provided in [90-sbctl.hook](file:///home/pyro/Development/projects/secure-boot/90-sbctl.hook).

13. **Reboot**:
    In some cases, you may need to manually re-enable Secure Boot. After booting, verify:
    ```bash
    sbctl status
    ```

> [!NOTE]
> The automation command provided in the original forum post:
> `sudo sbctl sign -s -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed /usr/lib/systemd/boot/efi/systemd-bootx64.efi`
> is specifically for `systemd-boot`. If you are using GRUB, use the script's logic or the provided `.hook` file.

## Files in this folder
- [setup.sh](file:///home/pyro/Development/projects/secure-boot/setup.sh): Interactive setup script.
- [README.md](file:///home/pyro/Development/projects/secure-boot/README.md): This guide.
- [90-sbctl.hook](file:///home/pyro/Development/projects/secure-boot/90-sbctl.hook): Example pacman hook for automatic signing.

## Credits
- [Unified Extensible Firmware Interface/Secure Boot - ArchWiki](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot)
- [Reddit Thread](https://www.reddit.com/r/archlinux/comments/10pq74e/my_easy_method_for_setting_up_secure_boot_with/)
- @stefanwimmer128 for clarifications
