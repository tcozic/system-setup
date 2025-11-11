#!/bin/bash

# Function to check if a package is installed
is_pac_installed() {
  pacman -Qi "$1" &> /dev/null
}

# Function to check if a package is installed
is_pac_group_installed() {
  pacman -Qg "$1" &> /dev/null
}

# Function to install packages if not already installed
install_pac_packages() {
  local packages=("$@")
  local to_install=()

  for pkg in "${packages[@]}"; do
    if ! is_pac_installed "$pkg" && ! is_pac_group_installed "$pkg"; then
      to_install+=("$pkg")
    fi
  done

  if [ ${#to_install[@]} -ne 0 ]; then
    echo "Installing: ${to_install[*]}"
    yay -S --noconfirm "${to_install[@]}"
  fi
} 

# Function to check if an apt package is installed
is_apt_installed() {
    # Check if the package is installed and has the "ok installed" status
    dpkg -s "$1" &> /dev/null
    return $?
}

# Function to install apt packages if not already installed
install_apt_packages() {
    local packages=("$@")
    local to_install=()

    # Check for the presence of apt before continuing
    if ! command -v apt &> /dev/null; then
        echo "Error: 'apt' command not found. Skipping APT installation."
        return 1
    fi

    for pkg in "${packages[@]}"; do
        if ! is_apt_installed "$pkg"; then
            to_install+=("$pkg")
        fi
    done

    if [ ${#to_install[@]} -ne 0 ]; then
        echo "Installing APT packages (Desktop Tools): ${to_install[*]}"
        # Ensure package list is updated and install missing packages non-interactively
        sudo apt-get update && sudo apt-get install -y "${to_install[@]}"
    else
        echo "All specified APT packages are already installed."
    fi
}

# Function to check if a brew package (formula or cask) is installed
is_brew_installed() {
    local pkg_name="$1"
    # Check if the name exists in the list of installed formulae or casks
    brew list --formula 2>/dev/null | grep -q "^${pkg_name}$" || brew list --cask 2>/dev/null | grep -q "^${pkg_name}$"
    return $?
}
# Function to install brew packages if not already installed
install_brew_packages() {
    local packages=("$@")
    local to_install=()
    local cask_packages=()

    # Check for the presence of brew before continuing
    if ! command -v brew &> /dev/null; then
        echo "Error: 'brew' command not found. Skipping Brew installation."
        return 1
    fi

    # Simple example to separate formulae and casks by convention (e.g., ends with '-cask')
    # For a simple list, installing all with 'brew install' is often sufficient,
    # but separating them allows for explicit handling if needed:
    for pkg in "${packages[@]}"; do
        if ! is_brew_installed "$pkg"; then
            # You can add logic here if you want to explicitly tag items as casks
            # Example: if [[ "$pkg" == *"-cask" ]]; then ...
            to_install+=("$pkg")
        fi
    done

    if [ ${#to_install[@]} -ne 0 ]; then
        echo "Installing Brew packages (CLI Tools): ${to_install[*]}"
        # brew install handles both formulae and casks without needing separate flags
        brew install "${to_install[@]}"
    else
        echo "All specified Brew packages are already installed."
    fi
}
# Function to install brew casks (GUI applications) if not already installed
install_brew_casks() {
    local packages=("$@")
    local to_install=()

    if ! command -v brew &> /dev/null; then
        echo "Error: 'brew' command not found. Skipping Brew Cask installation."
        return 1
    fi

    for pkg in "${packages[@]}"; do
        if ! is_brew_installed "$pkg"; then
            to_install+=("$pkg")
        fi
    done

    if [ ${#to_install[@]} -ne 0 ]; then
        echo "Installing Brew Casks (GUI Applications): ${to_install[*]}"
        # Explicitly install them as casks
        brew install --cask "${to_install[@]}"
    else
        echo "All specified Brew Casks are already installed."
    fi
}
# Function to check for and install Homebrew if missing
ensure_homebrew_installed() {
    if ! command -v brew &> /dev/null; then
        echo "Homebrew is not installed. Installing Homebrew..."
        # Installation command from https://brew.sh/
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Check if installation was successful
        if [ $? -eq 0 ]; then
            echo "Homebrew installed successfully!"

            # Post-install steps for Linux/macOS M1/M2 (required to add brew to PATH)
            if [[ "$OSTYPE" == "linux-gnu" ]]; then
                # On Linux, Homebrew installs to /home/linuxbrew/.linuxbrew/
                echo 'export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"' >> ~/.bashrc
                echo 'export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"' >> ~/.zshrc
                eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
            elif [[ "$(uname -m)" == "arm64" ]]; then
                # On Apple Silicon (M1/M2), Homebrew installs to /opt/homebrew/
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.bash_profile
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi

        else
            echo "Error: Homebrew installation failed."
            return 1
        fi
    else
        echo "Homebrew is already installed."
    fi
}
# Funtion to install TPM Tmux plugin manager if tmux is installed
# Function to install TPM Tmux plugin manager if tmux is installed
install_tpm() {
    if ! command -v tmux &> /dev/null; then
        echo "tmux is not installed."
        return 1
    fi
    
    TPM_DIR="$HOME/.tmux/plugins/tpm"
    
    # Check if TPM is already installed
    if [ -d "$TPM_DIR" ]; then
        echo "TPM is already installed in $TPM_DIR"
        return 0
    fi
    
    echo "Installing Tmux Plugin Manager (TPM)..."
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    
    if [ $? -ne 0 ]; then
        echo "Failed to clone TPM repository."
        return 1
    fi
    
    echo "TPM installed successfully!"
    echo "Now opening tmux session and installing plugins..."
    
    tmux new-session -d -s tpm_install_session
    # Using C-s as prefix. Change to C-b if using default prefix
    tmux send-keys -t tpm_install_session C-b "I" C-m
    tmux attach -t tpm_install_session
}

dotfiles_setup() {
    STOW_LIST=(.)  # Fixed: removed space before parenthesis
    ORIGINAL_DIR=$(pwd)
    REPO_URL="git@github.com:tcozic/dotfiles.git"  # You need to set this to your actual repo URL
    REPO_NAME=".dotfiles"
    
    if ! command -v stow &> /dev/null; then
        echo "Install stow first"
        return 1
    fi
    
    cd ~ || return 1  # Added error handling for cd
    
    # Check if the repository already exists
    if [ -d "$REPO_NAME" ]; then
        echo "Repository '$REPO_NAME' already exists. Skipping clone"
    else
        git clone "$REPO_URL" "$REPO_NAME"
        
        if [ $? -ne 0 ]; then
            echo "Failed to clone the repository."
            return 1
        fi
    fi
    
    cd "$REPO_NAME" || return 1  # Added error handling for cd
    
    if [ -f "./stow.conf" ]; then  # Fixed: removed space in condition
        source ./stow.conf
    fi
    
    stow --adopt  "${STOW_LIST[@]}"  # Fixed: proper array expansion syntax
    git stash 
    cd "$ORIGINAL_DIR" || return 1  # Return to original directory
}
# Function to install Zinit plugin manager for Zsh
install_zinit() {
    if ! command -v zsh &> /dev/null; then
        echo "zsh is not installed."
        return 1
    fi
    
    ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
    
    # Check if Zinit is already installed
    if [ -d "$ZINIT_HOME" ]; then
        echo "Zinit is already installed in $ZINIT_HOME"
        return 0
    fi
    
    echo "Installing Zinit plugin manager for Zsh..."
    
    # Create the directory structure
    mkdir -p "$(dirname "$ZINIT_HOME")"
    
    # Clone Zinit repository
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
    
    if [ $? -ne 0 ]; then
        echo "Failed to clone Zinit repository."
        return 1
    fi
    
    echo "Zinit installed successfully!"
    return 0
}
install_ohmyposh() {
  # Define the standard installation directories from the documentation
  local LOCAL_BIN="${HOME}/.local/bin"
  local USER_BIN="/usr/local/bin"
  
  # The actual binary path
  local OMP_BINARY="${LOCAL_BIN}/oh-my-posh"

  # Check if the binary exists in the primary (local) location
  if [ -f "$OMP_BINARY" ]; then
    echo "✅ Oh My Posh is already installed at $OMP_BINARY."
    return 0
  fi

  # Check if the binary exists in the alternative (system-wide) location
  # This covers installations done via the second method in the OMP documentation
  if [ -f "${USER_BIN}/oh-my-posh" ]; then
    echo "✅ Oh My Posh is already installed at ${USER_BIN}/oh-my-posh."
    return 0
  fi
  
  # If not found, proceed with installation using the curl | bash method
  echo "Installing Oh My Posh..."
  curl -s https://ohmyposh.dev/install.sh | bash -s
  
  # Note: The install.sh script places the binary in ~/.local/bin/oh-my-posh

  # Verify installation (Optional but highly recommended)
  if [ -f "$OMP_BINARY" ]; then
    echo "🎉 Oh My Posh installed successfully to $OMP_BINARY."
  else
    echo "❌ Installation failed or the binary was placed somewhere unexpected."
    return 1
  fi
}

install_nerd_font() {
    # 1. Check for the required argument (font name)
    if [ -z "$1" ]; then
        echo "❌ Error: Please provide the base name of the Nerd Font to install (e.g., JetBrainsMono)."
        echo "Usage: install_nerd_font <FontName>"
        return 1
    fi
local GITHUB_API="https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"
    
    # Use curl to fetch the release data and grep/sed to extract the tag_name
    local LATEST_TAG
    LATEST_TAG=$(curl -sL $GITHUB_API | grep '"tag_name":' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$LATEST_TAG" ]; then
        echo "❌ Error: Could not determine the latest Nerd Fonts release tag from GitHub."
        return 1
    fi
    local FONT_NAME="$1"
    local FONT_ZIP="${FONT_NAME}.zip"
    local FONTS_DIR="${HOME}/.fonts"

    local DOWNLOAD_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${LATEST_TAG}/${FONT_ZIP}"
    echo "Attempting to install Nerd Font: **${FONT_NAME}**"
    echo "---"

    # 2. Ensure the local fonts directory exists
    if [ ! -d "$FONTS_DIR" ]; then
        echo "Creating fonts directory: ${FONTS_DIR}"
        mkdir -p "$FONTS_DIR"
    fi

    # 3. Download the font zip file
    echo "Downloading from: ${DOWNLOAD_URL}"
    if ! wget -q -P "$FONTS_DIR" "$DOWNLOAD_URL"; then
        echo "❌ Error: Failed to download the font. Please verify the font name is correct and available in v3.0.2."
        return 1
    fi

    # 4. Navigate to the fonts directory
    cd "$FONTS_DIR" || { echo "❌ Error: Could not change directory to $FONTS_DIR"; return 1; }

    # 5. Unzip and remove the temporary zip file
    echo "Unzipping files..."
    if ! unzip -q -o "$FONT_ZIP"; then
        echo "❌ Error: Failed to unzip ${FONT_ZIP}. The downloaded file might be corrupted."
        rm -f "$FONT_ZIP" # Cleanup bad download
        return 1
    fi
    
    echo "Cleaning up zip file..."
    rm -f "$FONT_ZIP"

    # 6. Rebuild the font cache
    echo "Rebuilding font cache..."
    if ! fc-cache -fv > /dev/null; then
        echo "⚠️ Warning: Failed to rebuild font cache. You may need to run 'fc-cache -fv' manually."
    fi

    echo "---"
    echo "🎉 **Successfully installed ${FONT_NAME} Nerd Font!**"
    echo "You must now select this font in your terminal emulator or editor."
}
install_fzf(){
    local FZF_DIR="${HOME}/.fzf"
    
    echo "--- FZF Installation Check ---"
    
    # Check if 'fzf' binary is in PATH or if the source directory exists
    if command -v fzf &> /dev/null || [ -d "$FZF_DIR" ]; then
        echo "✅ FZF is already installed or source directory exists."
    else
        echo "⚠️ FZF binary not found. Installing from GitHub source..."
        
        # Install FZF from GitHub
        if git clone --depth 1 https://github.com/junegunn/fzf.git "$FZF_DIR"; then
            echo "Successfully cloned FZF repository."
            echo "Running FZF installer with automated choices (Key Bindings: Yes, Completion: Yes, Update .zshrc: No)."
            
            # Use printf to send automated inputs to the installer: y (key bindings), y (completion), n (update zshrc)
            printf "y\ny\nn\n" | "$FZF_DIR/install"
            
        else
            echo "❌ Error: Failed to clone FZF repository. Do you have 'git' installed?"
            return 1
        fi
    fi
}
install_neovim_utility() {
    echo "--- Neovim Installation Utility ---"
    
    local NEOVIM_ARCHIVE="nvim-linux-x86_64.tar.gz"
    local NEOVIM_DOWNLOAD_URL="https://github.com/neovim/neovim/releases/latest/download/$NEOVIM_ARCHIVE"
    local NEOVIM_INSTALL_DIR="/opt"
    
    # *** FINAL CORRECTION: Using the exact extracted folder name from your diagnostics ***
    local NEOVIM_FOLDER_NAME="nvim-linux-x86_64" 
    local NEOVIM_EXTRACTED_DIR="/opt/$NEOVIM_FOLDER_NAME"
    local BINARY_SOURCE="$NEOVIM_EXTRACTED_DIR/bin/nvim"
    # ************************************************************************************

    echo "Downloading latest Neovim stable release..."

    # 1. Download the latest tarball (in the current directory)
    # The -s flag is for silent to clean up curl output, but -L is critical for following redirects
    if ! curl -sLO "$NEOVIM_DOWNLOAD_URL"; then
        echo "❌ Error: Failed to download Neovim from GitHub."
        return 1
    fi
    
    # 2. Check for sudo permissions (crucial for /opt)
    if ! sudo -v &> /dev/null; then
        echo "🚨 Authentication required: You will be prompted for your password to proceed."
    fi

    # 3. Clean up any previous installation directory
    echo "Cleaning up old installation directory: $NEOVIM_EXTRACTED_DIR (requires sudo)..."
    if ! sudo rm -rf "$NEOVIM_EXTRACTED_DIR"; then
        echo "❌ Error: Failed to clean up previous Neovim directory."
        return 1
    fi

    # 4. Extract the new version to /opt
    echo "Extracting $NEOVIM_ARCHIVE to $NEOVIM_INSTALL_DIR (requires sudo)..."
    # The tarball is extracted to /opt, creating the nvim-linux-x86_64 directory inside.
    if ! sudo tar -C "$NEOVIM_INSTALL_DIR" -xzf "$NEOVIM_ARCHIVE"; then
        echo "❌ Error: Failed to extract Neovim archive."
        return 1
    fi
    
    # 5. Clean up the downloaded archive
    echo "Cleaning up downloaded file: $NEOVIM_ARCHIVE"
    rm -f "$NEOVIM_ARCHIVE"

    # 6. Verify installation 
    if [ -f "$BINARY_SOURCE" ]; then
        echo "✅ Neovim successfully installed to $NEOVIM_EXTRACTED_DIR."
    else
        echo "❌ Verification failed: Neovim binary not found at $BINARY_SOURCE."
        # This line should now ONLY fail if GitHub changes the file structure again.
        return 1
    fi
    
    # 7. Create symbolic link in a common PATH location
    local SYMLINK_TARGET="/usr/local/bin/nvim"

    echo "Creating symbolic link for 'nvim' (requires sudo)..."
    if ! sudo ln -sf "$BINARY_SOURCE" "$SYMLINK_TARGET"; then
        echo "⚠️ Warning: Failed to create symbolic link in $SYMLINK_TARGET."
    else
        echo "✅ Symbolic link created: You can now run 'nvim'."
    fi

    echo "--- Neovim Setup Complete ---"
    return 0
}
