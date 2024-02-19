#!/usr/bin/env bash

# Checking if running in repo folder
if [[ "$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]')" =~ ^scripts$ ]]; then
	echo "You are running this in 'salis' folder."
	echo "Please use ./salis.sh instead!"
	exit
fi

# Installing git
printf "\n[*] Installing git...\n\n"
pacman -Sy --noconfirm --needed git

# Cloning project
printf "\n[*] Cloning 'salis' project...\n\n"
git clone https://github.com/anisbsalah/salis.git

# Executing script
printf "\n[*] Executing 'salis.sh' script...\n\n"
cd "${HOME}/salis" || exit 1
exec ./salis.sh
