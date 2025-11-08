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
    
    stow "${STOW_LIST[@]}"  # Fixed: proper array expansion syntax
    
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
