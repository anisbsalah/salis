#!/usr/bin/env bash

BOLD=$(tput bold)
RESET=$(tput sgr0)

echo "
==============================================================================
   █████╗ ██████╗  ██████╗██╗  ██╗    ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗
  ██╔══██╗██╔══██╗██╔════╝██║  ██║    ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝
  ███████║██████╔╝██║     ███████║    ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝ 
  ██╔══██║██╔══██╗██║     ██╔══██║    ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗ 
  ██║  ██║██║  ██║╚██████╗██║  ██║    ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝    ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝
==============================================================================
            Automated Script For A Minimal Arch Linux Installation
==============================================================================

                         Arch Linux Base Installation

==============================================================================
"
CONFIG_FILE="${PROJECT_DIR}/setup.conf"

if [[ ! -f ${CONFIG_FILE} ]]; then # check if file exists
	touch -f "${CONFIG_FILE}"         # create file if not exists
fi

set_option() {
	if grep -Eq "^${1}.*" "${CONFIG_FILE}"; then # check if option exists
		sed -i -e "/^${1}.*/d" "${CONFIG_FILE}"     # delete option if exists
	fi
	echo "${1}=${2}" >>"${CONFIG_FILE}" # add option
}

set_password() {
	read -r -sp "${BOLD}[#?] $1 password: " PASSWORD1
	echo
	read -r -sp "${BOLD}[#?] Confirm password: " PASSWORD2
	echo
	if [[ ${PASSWORD1} == "${PASSWORD2}" ]]; then
		declare -n VARIABLE="$2"
		VARIABLE="${PASSWORD1}"
	else
		printf "ERROR! Passwords do not match. Try again.\n\n"
		set_password "$1" "$2"
	fi
}

read -erp "${BOLD}[#?] Hostname: ${RESET}" hostname
set_option HOSTNAME "${hostname}"
echo
read -erp "${BOLD}[#?] Username: ${RESET}" username
set_option USERNAME "${username,,}"
echo
set_password "Root" "root_password"
set_option ROOT_PASSWORD "${root_password}"
echo
set_password "User" "user_password"
set_option USER_PASSWORD "${user_password}"
echo
read -erp "${BOLD}[#?] Keyboard layout (e.g. fr): ${RESET}" keyboard_layout
set_option KEYBOARD_LAYOUT "${keyboard_layout}"
echo
read -erp "${BOLD}[#?] Timezone (e.g. Africa/Tunis): ${RESET}" timezone
set_option TIMEZONE "${timezone}"

clear

echo "
==============================================================================
 Listing information about block devices
==============================================================================
"
# List information about block devices
lsblk

echo "
==============================================================================
 Setting the disk to install Arch Linux on
==============================================================================
"
# Set the disk device you want to install Arch Linux on
read -erp "${BOLD}[#?] Set the disk device you want to install Arch Linux on (e.g. /dev/sda): ${RESET}" DISK
set_option DISK "${DISK}"

# Print the disk information
echo "> Disk information for ${DISK}:"
sgdisk -p "${DISK}"

# Make sure everything is unmounted before we start
umount -A --recursive /mnt

clear

echo "
==============================================================================
 Wiping DATA on ${DISK} & Creating a new GPT table
==============================================================================
"
# Confirm the data wipe
read -erp "${BOLD}:: Are you sure you want to wipe all data on ${DISK}? [y/N]: ${RESET}" CONFIRM
if [[ ${CONFIRM} != [Yy][Ee][Ss] && ${CONFIRM} != [Yy] ]]; then
	echo "Aborted."
	exit 1
fi

# Wipe the disk
echo "[*] Wiping all data on ${DISK}..."
sgdisk --zap-all "${DISK}"

# Create a new GPT table
echo "[*] Creating a new GPT table on ${DISK}..."
sgdisk --set-alignment=2048 --clear "${DISK}"

echo "
==============================================================================
 Partitioning the disk & Formatting the partitions
==============================================================================
"
bios_gpt_auto_partitions() {
	# Create a BIOS boot partition
	echo "[*] Creating a BIOS boot partition on ${DISK}..."
	sgdisk --new=1::+1M --typecode=1:ef02 --change-name=1:"BIOS Boot" "${DISK}"
	# Create a ROOT partition
	echo "[*] Creating a root partition with Btrfs filesystem on ${DISK}..."
	sgdisk --new=2::-0 --typecode=2:8300 --change-name=2:"ArchLinux Root" "${DISK}"
	# Notify the kernel about the changes made to the partition table
	reread_partition_table
	ROOT_PARTITION=$(fdisk -l "${DISK}" | grep "^${DISK}" | awk '{print $1}' | awk 'NR==2')
}

uefi_gpt_auto_partitions() {
	# Create a BIOS boot partition
	echo "[*] Creating a BIOS boot partition on ${DISK}..."
	sgdisk --new=1::+1M --typecode=1:ef02 --change-name=1:"BIOS Boot" "${DISK}"
	# Create an EFI System partition
	echo "[*] Creating an EFI System partition on ${DISK}..."
	sgdisk --new=2::+1024M --typecode=2:ef00 --change-name=2:"EFI System Partition" "${DISK}"
	# Create a ROOT partition
	echo "[*] Creating a root partition with Btrfs filesystem on ${DISK}..."
	sgdisk --new=3::-0 --typecode=3:8300 --change-name=3:"ArchLinux Root" "${DISK}"
	# Notify the kernel about the changes made to the partition table
	reread_partition_table
	EFI_PARTITION=$(fdisk -l "${DISK}" | grep "^${DISK}" | awk '{print $1}' | awk 'NR==2')
	ROOT_PARTITION=$(fdisk -l "${DISK}" | grep "^${DISK}" | awk '{print $1}' | awk 'NR==3')
}

reread_partition_table() {
	partprobre "${DISK}"
	sleep 3
}

# Create subvolumes for root, home, .snapshots, swap, tmp and var/log directories
create_subvolumes() {
	echo "[*] Creating subvolumes for root, home, .snapshots, swap, tmp and var/log directories..."
	btrfs subvolume create /mnt/@
	btrfs subvolume create /mnt/@home
	btrfs subvolume create /mnt/@snapshots
	btrfs subvolume create /mnt/@swap
	btrfs subvolume create /mnt/@tmp
	btrfs subvolume create /mnt/@var_log
}

# Mount the subvolumes
mount_subvolumes() {
	echo "[*] Mounting the subvolumes..."
	mount -o noatime,compress=zstd,commit=120,subvol=@ "${ROOT_PARTITION}" /mnt
	mkdir -p /mnt/{home,.snapshots,swap,tmp,var/log}
	mount -o noatime,compress=zstd,commit=120,subvol=@home "${ROOT_PARTITION}" /mnt/home
	mount -o noatime,compress=zstd,commit=120,subvol=@snapshots "${ROOT_PARTITION}" /mnt/.snapshots
	mount -o noatime,compress=zstd,commit=120,subvol=@swap "${ROOT_PARTITION}" /mnt/swap
	mount -o noatime,compress=zstd,commit=120,subvol=@tmp "${ROOT_PARTITION}" /mnt/tmp
	mount -o noatime,compress=zstd,commit=120,subvol=@var_log "${ROOT_PARTITION}" /mnt/var/log
}

# Set up btrfs subvolumes
subvolumes_setup() {
	create_subvolumes
	umount /mnt
	mount_subvolumes
}

# Mount the EFI System partition
mount_efi_partition() {
	echo "[*] Mounting the EFI System partition..."
	mount --mkdir "${EFI_PARTITION}" /mnt/boot
}

# Partition the disk, format and mount the partitions
if [[ -d "/sys/firmware/efi" ]]; then
	# Auto partitioning (UEFI/GPT layout)
	uefi_gpt_auto_partitions
	# Format the EFI System partition as fat32
	echo "[*] Formatting the EFI System partition as fat32..."
	mkfs.fat -F 32 "${EFI_PARTITION}"
	# Format the root partition as btrfs
	echo "[*] Formatting the root partition as btrfs..."
	mkfs.btrfs -f "${ROOT_PARTITION}"
	# Mount the root partition
	echo "[*] Mounting the root partition..."
	mount "${ROOT_PARTITION}" /mnt
	# Subvolumes setup
	subvolumes_setup
	# Mount the EFI System partition
	mount_efi_partition
else
	# Auto partitioning (BIOS/GPT layout)
	bios_gpt_auto_partitions
	# Format the root partition as btrfs
	echo "[*] Formatting the root partition as btrfs..."
	mkfs.btrfs -f "${ROOT_PARTITION}"
	# Mount the root partition
	echo "[*] Mounting the root partition..."
	mount "${ROOT_PARTITION}" /mnt
	# Subvolumes setup
	subvolumes_setup
fi

# If mounting failed, reboot
if ! grep -qs '/mnt' /proc/mounts; then
	echo "Drive is not mounted! Can not continue." && sleep 1
	echo "Rebooting in 3s..." && sleep 1
	echo "Rebooting in 2s..." && sleep 1
	echo "Rebooting in 1s..." && sleep 1
	reboot now
fi

echo "
==============================================================================
 Installing prerequisites
==============================================================================
"
# Installing Prerequisites
sed -i 's/^[#[:space:]]*ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
sed -i 's/^[#[:space:]]*Color/Color\nILoveCandy/' /etc/pacman.conf
pacman -S --noconfirm archlinux-keyring # Update keyrings to latest to prevent packages failing to install
pacman -S --noconfirm --needed arch-install-scripts
pacman -S --noconfirm --needed curl reflector rsync

country_iso=$(curl -4 ifconfig.co/country-iso)
echo "
==============================================================================
 Setting up ${country_iso} mirrors for faster downloads
==============================================================================
"
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

# Ranking mirrors by country
reflector --verbose --download-timeout 60 \
	--country "${country_iso}" \
	--protocol https \
	--age 24 \
	--latest 20 \
	--fastest 10 \
	--sort rate \
	--save /etc/pacman.d/mirrorlist

echo "
==============================================================================
 Installing essential packages
==============================================================================
"
base_pkgs=("base" "base-devel")
kernel_pkgs=("linux" "linux-headers" "linux-docs")
firmware_pkgs=("linux-firmware" "sof-firmware")
doc_pkgs=("man-db" "man-pages" "texinfo")
extra_pkgs=("bash-completion" "btrfs-progs" "git" "nano" "reflector" "sudo" "terminus-font" "zstd")

# Install the base system
pacstrap -K /mnt "${base_pkgs[@]}" "${kernel_pkgs[@]}" "${firmware_pkgs[@]}" "${doc_pkgs[@]}" "${extra_pkgs[@]}"

echo "
==============================================================================
 Generating fstab
==============================================================================
"
# Generate fstab
genfstab -U /mnt >>/mnt/etc/fstab
echo "> Generated /etc/fstab:
"
cat /mnt/etc/fstab

echo "
==============================================================================
 Swap file creation
==============================================================================
"
# Create swap file
ram=$(free -m -t | awk 'NR == 2 {print $2}')
result=$((ram < 4096 ? ram : 4096))
result=$((result + ((ram - 4096 > 0 ? ram - 4096 : 0) / 2)))
result=$((result < 32 * 1024 ? result : 32 * 1024))
SWAPFILE_SIZE="${result}"
btrfs filesystem mkswapfile --size "${SWAPFILE_SIZE}M" --uuid clear /mnt/swap/swapfile
swapon /mnt/swap/swapfile
echo '# Swap
/swap/swapfile none swap defaults 0 0' >>/mnt/etc/fstab

# ============================================================================

# Copy 'salis' directory to the new system
cp -R "${PROJECT_DIR}" /mnt/root/salis

echo "
==============================================================================

       Done with 1-arch-install.sh  -  System Ready for 2-arch-setup.sh

==============================================================================
"
sleep 1
clear
exit 0
