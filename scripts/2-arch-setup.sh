#!/usr/bin/env bash

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

                               Arch Linux Setup 

==============================================================================
"
echo "[*] source ${HOME}/salis/setup.conf ..."
source "${HOME}/salis/setup.conf"

echo "
==============================================================================
 Timezone
==============================================================================
"
# Set the time zone
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc

echo "
==============================================================================
 Localization
==============================================================================
"
# Uncomment the desired locale in /etc/locale.gen
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#ar_TN.UTF-8 UTF-8/ar_TN.UTF-8 UTF-8/' /etc/locale.gen
# Generate the locale
locale-gen

# Set the system language
{
	echo 'LANG=en_US.UTF-8'
	echo 'LC_TIME=C'
} >>/etc/locale.conf

# Set the console keyboard layout
echo "KEYMAP=${KEYBOARD_LAYOUT}" >>/etc/vconsole.conf
# Set the console font
echo 'FONT=ter-v18b' >>/etc/vconsole.conf

echo "
==============================================================================
 Hostname
==============================================================================
"
# Set the hostname
echo "${HOSTNAME}" >/etc/hostname

# Local network hostname resolution
{
	echo '127.0.0.1 localhost'
	echo '::1 		 localhost'
	echo "127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}"
} >>/etc/hosts

echo "
==============================================================================
 Network configuration
==============================================================================
"
# Complete the network configuration for the newly installed environment
pacman -S --noconfirm --needed networkmanager
systemctl enable NetworkManager.service

echo "
==============================================================================
 Initramfs
==============================================================================
"
# Initramfs
sed -i 's/MODULES=()/MODULES=(btrfs)/' /etc/mkinitcpio.conf
sed -i 's/BINARIES=()/BINARIES=(setfont)/' /etc/mkinitcpio.conf
sed -i 's/^#COMPRESSION="ZSTD"/COMPRESSION="ZSTD"/' /etc/mkinitcpio.conf
mkinitcpio -P

echo "
==============================================================================
 Root password
==============================================================================
"
# Set the root password
echo "root:${ROOT_PASSWORD}" | chpasswd

echo "
==============================================================================
 Boot loader
==============================================================================
"
# Install boot loader
echo "[*] Installing GRUB boot loader..."
if [[ ! -d "/sys/firmware/efi" ]]; then
	pacman -S --noconfirm --needed grub dosfstools mtools os-prober
	grub-install --target=i386-pc "${DISK}"
	grub-mkconfig -o /boot/grub/grub.cfg
else
	pacman -S --noconfirm --needed grub efibootmgr dosfstools mtools os-prober
	grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
	grub-mkconfig -o /boot/grub/grub.cfg
fi

echo "
==============================================================================
 User management
==============================================================================
"
# Add user
useradd -m -g users -G audio,video,network,wheel,storage,rfkill -s /bin/bash "${USERNAME}"
printf "User '%s' created and added to audio,video,network,wheel,storage,rfkill Groups.\nHome directory created.\nDefault shell set to: /bin/bash\n" "${USERNAME}"
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd

# Add sudo rights to group wheel
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Copy project to user home directory
cp -R "${HOME}/salis" "/home/${USERNAME}/"
chown -R "${USERNAME}": "/home/${USERNAME}/salis"
echo "'salis' copied to home directory"

echo "
==============================================================================
 'pacman' configuration
==============================================================================
"
# Configure 'pacman'
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
echo "[*] Updating database..."
pacman -Sy

echo "
==============================================================================
 Microcode
==============================================================================
"
# Determine processor type and install microcode
PROC_TYPE=$(lscpu)
if grep -E "GenuineIntel" <<<"${PROC_TYPE}"; then
	echo "[*] Installing Intel microcode..."
	pacman -S --noconfirm --needed intel-ucode
elif grep -E "AuthenticAMD" <<<"${PROC_TYPE}"; then
	echo "[*] Installing AMD microcode..."
	pacman -S --noconfirm --needed amd-ucode
fi

echo "
==============================================================================
 Display server
==============================================================================
"
# Install Xorg display server
echo "[*] Installing Xorg..."
pacman -S --noconfirm --needed xorg xorg-apps xorg-xinit

echo "
==============================================================================
 Drivers
==============================================================================
"
# Install graphics card drivers
echo "[*] Installing graphics card drivers..."
GPU_TYPE=$(lspci -v | grep -A1 -e VGA -e 3D)
if grep -E "NVIDIA|GeForce" <<<"${GPU_TYPE}"; then
	pacman -S --noconfirm --needed xf86-video-nouveau mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader
elif grep -E "Radeon|AMD" <<<"${GPU_TYPE}"; then
	pacman -S --noconfirm --needed xf86-video-amdgpu mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau libva-vdpau-driver lib32-libva-vdpau-driver
elif grep -E "Integrated Graphics Controller" <<<"${GPU_TYPE}"; then
	pacman -S --noconfirm --needed xf86-video-intel mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader vulkan-intel lib32-vulkan-intel libvdpau-va-gl libva-intel-driver libva-utils
elif grep -E "Intel Corporation UHD" <<<"${GPU_TYPE}"; then
	pacman -S --noconfirm --needed xf86-video-intel mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader vulkan-intel lib32-vulkan-intel libvdpau-va-gl libva-intel-driver libva-utils
fi

# Install input drivers
echo "[*] Installing input drivers..."
pacman -S --noconfirm --needed libinput xf86-input-libinput xf86-input-evdev xf86-input-elographics xf86-input-synaptics

# Install necessary drivers for wireless card
WIRELESS_CARD=$(lspci -v | grep -i network)
if grep -E "Broadcom" <<<"${WIRELESS_CARD}"; then
	if grep -E "BCM43" <<<"${WIRELESS_CARD}"; then
		echo "[*] Installing wireless card drivers..."
		pacman -S --noconfirm --needed dkms broadcom-wl-dkms
	fi
fi

echo "
==============================================================================
 Xorg/Keyboard configuration
==============================================================================
"
echo "  Set X11 keymap to: ${KEYBOARD_LAYOUT}"
mkdir -p /etc/X11/xorg.conf.d
cat >>"/etc/X11/xorg.conf.d/00-keyboard.conf" <<EOF
# Written by systemd-localed(8), read by systemd-localed and Xorg. It's
# probably wise not to edit this file manually. Use localectl(1) to
# update this file.
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "${KEYBOARD_LAYOUT}"
EndSection
EOF

echo "
==============================================================================
 Cleaning
==============================================================================
"
rm -rv "${HOME}/salis"
rm -rv "/home/${USERNAME}/salis"

echo "
==============================================================================
"
exit 0
