#!/bin/bash

# Garuda Secure Boot Setup Script
# Based on the guide for Garuda Linux with GRUB
# Credits: ArchWiki, Reddit, @stefanwimmer128

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Garuda Secure Boot Setup ===${NC}"
echo -e "This script will help you configure Secure Boot using sbctl."
echo -e "Ensure you have placed your UEFI in ${YELLOW}Setup Mode${NC} before continuing.\n"

read -p "Continue? (y/N): " confirm
if [[ $confirm != [yY] ]]; then
    echo "Aborted."
    exit 1
fi

# 1. Install/Update GRUB with Secure Boot support
echo -e "\n${BLUE}[1/8] Reinstalling GRUB with TPM and shim-lock disabled...${NC}"
sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=garuda --modules="tpm" --disable-shim-lock

# 2. Check/Install sbctl
echo -e "\n${BLUE}[2/8] Checking for sbctl...${NC}"
if ! command -v sbctl &> /dev/null; then
    echo -e "${YELLOW}sbctl not found. Installing...${NC}"
    sudo pacman -S --noconfirm sbctl
fi

echo -e "\n${BLUE}Current sbctl status:${NC}"
sbctl status

# 3. Regenerate GRUB config
echo -e "\n${BLUE}[3/8] Regenerating GRUB configuration...${NC}"
sudo grub-mkconfig -o /boot/grub/grub.cfg

# 4. Create Keys
echo -e "\n${BLUE}[4/8] Creating custom Secure Boot keys...${NC}"
sudo sbctl create-keys

# 5. Enroll Keys
echo -e "\n${BLUE}[5/8] Enrolling keys (including Microsoft's CA)...${NC}"
sudo sbctl enroll-keys -m -f

echo -e "\n${BLUE}Verification of enrollment:${NC}"
sbctl status

# 6. Sign unsigned files
echo -e "\n${BLUE}[6/8] Identifying and signing unsigned files...${NC}"
mapfile -t FILES_TO_SIGN < <(sudo sbctl verify | awk '/✗/{print $2}' || true)

if [ ${#FILES_TO_SIGN[@]} -eq 0 ]; then
    echo -e "${GREEN}No files need signing.${NC}"
else
    for file in "${FILES_TO_SIGN[@]}"; do
        echo -e "Signing: ${YELLOW}$file${NC}"
        if ! sudo sbctl sign -s "$file"; then
            echo -e "${RED}Error signing $file. It might be immutable.${NC}"
            echo -e "If caused by an immutable efivar, run: sudo chattr -i /sys/firmware/efi/efivars/<variable_name>"
        fi
    done
fi

# 7. Sign Linux images specifically
echo -e "\n${BLUE}[7/8] Ensuring all Linux images are signed...${NC}"
while IFS= read -r img; do
    echo -e "Signing kernel image: ${YELLOW}$img${NC}"
    sudo sbctl sign -s "$img"
done < <(find /boot -maxdepth 1 -name 'vmlinuz-*')

# 8. Final Verification
echo -e "\n${BLUE}[8/8] Final verification...${NC}"
sudo sbctl verify

echo -e "\n${GREEN}=== Setup Complete ===${NC}"
echo -e "1. Reboot your system."
echo -e "2. Re-enable Secure Boot in UEFI if necessary."
echo -e "3. After booting, run 'sbctl status' to confirm Secure Boot is active."
echo -e "\n${YELLOW}Note: To automate signing during updates, ensure the sbctl pacman hook is active.${NC}"
