#!/bin/bash

# Garuda Secure Boot Setup Script
# Based on the guide for Garuda Linux with GRUB

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Garuda Secure Boot Setup ===${NC}"
echo -e "This script will help you configure Secure Boot using sbctl."
echo -e "Ensure you have placed your UEFI in ${YELLOW}Setup Mode${NC} before continuing.\n"

read -r -p "Continue? (y/N): " confirm
if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
    echo "Aborted."
    exit 1
fi

echo -e "\n${BLUE}[1/8] Reinstalling GRUB with TPM and shim-lock disabled...${NC}"
sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=garuda --modules="tpm" --disable-shim-lock

echo -e "\n${BLUE}[2/8] Checking for sbctl...${NC}"
if ! command -v sbctl &> /dev/null; then
    echo -e "${YELLOW}sbctl not found. Installing...${NC}"
    sudo pacman -S --noconfirm sbctl
fi

echo -e "\n${BLUE}Current sbctl status:${NC}"
sbctl status

echo -e "\n${BLUE}[3/8] Regenerating GRUB configuration...${NC}"
sudo grub-mkconfig -o /boot/grub/grub.cfg

echo -e "\n${BLUE}[4/8] Creating custom Secure Boot keys...${NC}"
sudo sbctl create-keys

echo -e "\n${BLUE}[5/8] Enrolling keys (including Microsoft's CA)...${NC}"
sudo sbctl enroll-keys -m -f

echo -e "\n${BLUE}Verification of enrollment:${NC}"
sbctl status

echo -e "\n${BLUE}[6/8] Explicitly signing core boot components...${NC}"

GRUB_EFI="/boot/efi/EFI/garuda/grubx64.efi"
if [ -f "$GRUB_EFI" ]; then
    echo -e "Signing GRUB bootloader: ${YELLOW}$GRUB_EFI${NC}"
    sudo sbctl sign -s "$GRUB_EFI" || true
else
    echo -e "${YELLOW}Warning: GRUB EFI binary not found at $GRUB_EFI${NC}"
fi

while IFS= read -r img; do
    echo -e "Signing kernel image: ${YELLOW}$img${NC}"
    sudo sbctl sign -s "$img" || true
done < <(find /boot -maxdepth 1 -name 'vmlinuz-*')

echo -e "\n${BLUE}[7/8] Identifying and signing remaining unsigned files...${NC}"
# Use sed to reliably extract file paths, ignoring potential color codes
mapfile -t FILES_TO_SIGN < <(sudo sbctl verify | sed -n 's/.*✗ \([^ ]*\).*/\1/p' || true)

if [ ${#FILES_TO_SIGN[@]} -eq 0 ]; then
    echo -e "${GREEN}All target files are signed.${NC}"
else
    for file in "${FILES_TO_SIGN[@]}"; do
        echo -e "Signing: ${YELLOW}$file${NC}"
        if ! sudo sbctl sign -s "$file"; then
            echo -e "${YELLOW}Attempting to remove immutable flag for $file...${NC}"
            sudo chattr -i "$file" 2>/dev/null || true
            if ! sudo sbctl sign -s "$file"; then
                echo -e "${RED}Critical Error: Failed to sign $file.${NC}"
            fi
        fi
    done
fi

echo -e "\n${BLUE}[8/8] Final verification...${NC}"
sudo sbctl verify

echo -e "\n${GREEN}=== Setup Complete ===${NC}"
echo -e "1. Reboot your system."
echo -e "2. Re-enable Secure Boot in UEFI if necessary."
echo -e "3. After booting, run 'sbctl status' to confirm Secure Boot is active."
echo -e "\n${YELLOW}Note: Ensure the pacman hook (90-sbctl.hook) is placed in /etc/pacman.d/hooks/ to automate signing on updates.${NC}"