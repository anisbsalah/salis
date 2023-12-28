#!/usr/bin/env bash

# Checking if running in repo folder
if [[ "$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]')" =~ ^scripts$ ]]; then
	echo "You are running this in 'salis' folder."
	echo "Please use ./salis.sh instead!"
	exit
fi

# Installing git
echo "[*] Installing git..."
pacman -Sy --noconfirm --needed git

# Cloning project
echo "[*] Cloning 'salis' project..."
git clone https://github.com/anisbsalah/salis.git

# Executing script
echo "[*] Executing 'salis.sh' script..."
cd "${HOME}/salis" || exit 1
exec ./salis.sh
