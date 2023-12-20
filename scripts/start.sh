#!/bin/bash

# Checking if running in Repo Folder
if [[ "$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]')" =~ ^scripts$ ]]; then
	echo "You are running this in 'salis' Folder."
	echo "Please use ./salis.sh instead!"
	exit
fi

# Installing git
echo "[*] Installing git..."
pacman -Sy --noconfirm --needed git

# Cloning Project
echo "[*] Cloning 'salis' Project..."
git clone https://github.com/anisbsalah/salis.git

# Executing Script
echo "[*] Executing 'salis.sh' Script..."
cd "${HOME}/salis" || exit 1
exec ./salis.sh
