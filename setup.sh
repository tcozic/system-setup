#!/bin/bash

# Print the logo
# Parse command line arguments
DESKTOP_INSTALL=false
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --desktop) DESKTOP_INSTALL=true; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
done

# Clear screen 
clear

# Exit on any error
set -e

# Source utility functions
source utils.sh

# Source the package list
if [ ! -f "packages.conf" ]; then
  echo "Error: packages.conf not found!"
  exit 1
fi

source packages.conf

if [[ "$DESKTOP_INSTALL" == true ]]; then
  echo "Starting full install with desktop tools"
else
  echo "Starting CLI tools install only"
fi

# Update the system first
echo "Updating system..."
sudo apt update
echo "Checking homebrew"
ensure_homebrew_installed

echo "Installing CLI tools..."
install_brew_packages "${BREW_CLI_DEV_TOOLS[@]}"
# Install all packages
echo "Installing Nerds Fonts..."
install_brew_casks "${NERDS_FONTS[@]}"
echo "Installing TPM"
install_tpm
echo "Setting up stowed config"
dotfiles_setup
if [[ "$DESKTOP_INSTALL" == true ]]; then
	echo "Installing APT DESKTOP TOOLS"
	install_apt_packages "${APT_DESKTOP_TOOLS[@]}"

	# Install gnome specific things to make it like a tiling WM
	echo "Installing Gnome extensions..."
	#. gnome/gnome-extensions.sh
	echo "Setting Gnome hotkeys..."
	#. gnome/gnome-hotkeys.sh
	echo "Configuring Gnome..."
	#. gnome/gnome-settings.sh
fi

echo "Setup complete! You may want to reboot your system."
