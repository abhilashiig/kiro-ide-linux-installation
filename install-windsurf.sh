#!/usr/bin/env bash

# Windsurf Installer Script
# This script installs Windsurf on any Linux distribution, inspired by the Kiro installer.

set -e

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default installation directories
DEFAULT_INSTALL_DIR="/opt/windsurf"
USER_INSTALL_DIR="$HOME/.local/share/windsurf"

# Application information
APP_NAME="Windsurf"
APP_COMMENT="Windsurf - The first agentic IDE, and then some."

# Metadata and download URLs
METADATA_URL="https://windsurf-stable.codeium.com/api/update/linux-x64/stable/latest"
TEMP_DIR="/tmp/windsurf_install_$(date +%s)"
TEMP_METADATA_FILE="$TEMP_DIR/metadata.json"
TEMP_ARCHIVE_FILE="$TEMP_DIR/windsurf.tar.gz"

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}      Windsurf Installer Script      ${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo
}

# Function to fetch metadata and latest version information
fetch_metadata() {
    echo -e "${YELLOW}Fetching latest Windsurf metadata...${NC}"
    
    mkdir -p "$TEMP_DIR"
    
    if ! curl -s "$METADATA_URL" -o "$TEMP_METADATA_FILE"; then
        echo -e "${RED}Error: Failed to download metadata from $METADATA_URL${NC}"
        return 1
    fi
    
    if [ ! -s "$TEMP_METADATA_FILE" ]; then
        echo -e "${RED}Error: Downloaded metadata file is empty${NC}"
        return 1
    fi
    
    # Parse current version using jq
    CURRENT_VERSION=$(jq -r '.productVersion' "$TEMP_METADATA_FILE")
    if [ -z "$CURRENT_VERSION" ] || [ "$CURRENT_VERSION" == "null" ]; then
        echo -e "${RED}Error: Could not determine current version from metadata${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Latest version available: $CURRENT_VERSION${NC}"
    return 0
}

# Function to get the currently installed Windsurf version
get_installed_version() {
    local install_dir="$1"
    local installed_version=""
    
    if [ ! -d "$install_dir" ]; then
        echo ""
        return 1
    fi
    
    # Primary method: check the 'version' file created by this script
    if [ -f "$install_dir/version" ]; then
        installed_version=$(cat "$install_dir/version" | head -n 1 | tr -d ' \n\r')
    fi

    # Fallback: check executable --version flag
    if [ -z "$installed_version" ] && [ -f "$install_dir/windsurf" ]; then
        installed_version=$("$install_dir/windsurf" --version 2>/dev/null | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    fi
    
    # Fallback: check resources/app/package.json
    if [ -z "$installed_version" ] && [ -f "$install_dir/resources/app/package.json" ]; then
        installed_version=$(jq -r '.version // empty' "$install_dir/resources/app/package.json" 2>/dev/null)
    fi
    
    echo "$installed_version"
    return 0
}

# Function to compare version strings (returns 0 if v1 >= v2, 1 if v1 < v2)
version_compare() {
    local v1="$1"
    local v2="$2"
    
    if [ -z "$v1" ]; then return 1; fi # No version installed, update needed
    if [ -z "$v2" ]; then return 0; fi # No remote version, don't update
    
    if printf '%s\n%s\n' "$v1" "$v2" | sort -V -C 2>/dev/null; then
        if [ "$v1" = "$v2" ]; then return 0; else return 1; fi # v1 <= v2
    else
        return 0 # v1 > v2
    fi
}

# Function to check if update is needed
check_update_needed() {
    local install_dir="$1"
    local force_update="${2:-false}"
    
    if [ "$force_update" = true ]; then
        echo -e "${YELLOW}Force update requested, skipping version check.${NC}"
        return 0
    fi
    
    local installed_version
    installed_version=$(get_installed_version "$install_dir")
    
    if [ -z "$installed_version" ]; then
        echo -e "${YELLOW}No existing Windsurf installation found. Proceeding with fresh installation.${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Currently installed version: $installed_version${NC}"
    
    if [ -z "$CURRENT_VERSION" ]; then
        if ! fetch_metadata; then
            echo -e "${RED}Error: Could not fetch latest version information.${NC}"
            return 1
        fi
    fi
    
    if version_compare "$installed_version" "$CURRENT_VERSION"; then
        echo -e "${GREEN}Windsurf is already up to date (version $installed_version).${NC}"
        echo -e "${BLUE}Use --force flag to reinstall anyway.${NC}"
        return 1
    else
        echo -e "${YELLOW}Update available: $installed_version → $CURRENT_VERSION${NC}"
        return 0
    fi
}

# Function to download Windsurf package
download_windsurf_package() {
    echo -e "${YELLOW}Downloading Windsurf package...${NC}"
    
    local PACKAGE_URL=$(jq -r '.url' "$TEMP_METADATA_FILE")
    
    echo -e "${YELLOW}Downloading from: $PACKAGE_URL${NC}"
    if ! curl -L "$PACKAGE_URL" -o "$TEMP_ARCHIVE_FILE"; then
        echo -e "${RED}Error: Failed to download Windsurf package${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Extracting Windsurf package...${NC}"
    mkdir -p "$TEMP_DIR/extracted"
    if ! tar -xzf "$TEMP_ARCHIVE_FILE" -C "$TEMP_DIR/extracted"; then
        echo -e "${RED}Error: Failed to extract Windsurf package${NC}"
        return 1
    fi
    
    # The extracted folder is usually named 'Windsurf-linux-x64' or similar
    local EXTRACTED_DIR=$(find "$TEMP_DIR/extracted" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    
    if [ -d "$EXTRACTED_DIR" ]; then
        # Move contents up for easier access
        mv "$EXTRACTED_DIR"/* "$TEMP_DIR/extracted/"
        rmdir "$EXTRACTED_DIR" 2>/dev/null || true
    fi
    
    return 0
}

check_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${NC}"
    
    DEPS=("curl" "tar" "jq")
    MISSING_DEPS=()
    
    for dep in "${DEPS[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            MISSING_DEPS+=("$dep")
        fi
    done
    
    if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
        echo -e "${YELLOW}The following dependencies are missing: ${MISSING_DEPS[*]}${NC}"
        
        if command -v apt-get &> /dev/null; then
            echo -e "${YELLOW}Attempting to install with apt...${NC}"
            sudo apt-get update && sudo apt-get install -y "${MISSING_DEPS[@]}"
        elif command -v dnf &> /dev/null; then
            echo -e "${YELLOW}Attempting to install with dnf...${NC}"
            sudo dnf install -y "${MISSING_DEPS[@]}"
        elif command -v yum &> /dev/null; then
            echo -e "${YELLOW}Attempting to install with yum...${NC}"
            sudo yum install -y "${MISSING_DEPS[@]}"
        elif command -v pacman &> /dev/null; then
            echo -e "${YELLOW}Attempting to install with pacman...${NC}"
            sudo pacman -Sy --noconfirm --needed "${MISSING_DEPS[@]}"
        elif command -v zypper &> /dev/null;
            echo -e "${YELLOW}Attempting to install with zypper...${NC}"
            sudo zypper install -y "${MISSING_DEPS[@]}"
        else
            echo -e "${RED}Could not detect package manager. Please install dependencies manually: ${MISSING_DEPS[*]}${NC}"
            exit 1
        fi
        
        for dep in "${MISSING_DEPS[@]}"; do
            if ! command -v "$dep" &> /dev/null; then
                echo -e "${RED}Failed to install $dep. Please install it manually.${NC}"
                exit 1
            fi
        done
    fi
    
    echo -e "${GREEN}All dependencies are satisfied.${NC}"
}

install_windsurf() {
    local user_only=false
    local force_update=false
    
    for arg in "$@"; do
        case $arg in
            --user) user_only=true ;;
            --force) force_update=true ;;
        esac
    done

    local INSTALL_DIR=$DEFAULT_INSTALL_DIR
    if [ "$user_only" = true ]; then
        INSTALL_DIR=$USER_INSTALL_DIR
    fi

    if ! fetch_metadata; then exit 1; fi
    if ! check_update_needed "$INSTALL_DIR" "$force_update"; then return 0; fi
    if ! download_windsurf_package; then exit 1; fi
    
    local SOURCE_DIR="$TEMP_DIR/extracted"
    
    if [ ! -f "$SOURCE_DIR/windsurf" ]; then
        echo -e "${RED}Error: Invalid package extracted. Missing 'windsurf' executable.${NC}"
        exit 1
    fi
    
    local SYMLINK_DIR
    local DESKTOP_DIR
    local NEED_SUDO=true
    
    if [ "$user_only" = true ]; then
        INSTALL_DIR="$USER_INSTALL_DIR"
        SYMLINK_DIR="$HOME/.local/bin"
        DESKTOP_DIR="$HOME/.local/share/applications"
        NEED_SUDO=false
        mkdir -p "$SYMLINK_DIR" "$DESKTOP_DIR"
    else
        INSTALL_DIR="$DEFAULT_INSTALL_DIR"
        SYMLINK_DIR="/usr/local/bin"
        DESKTOP_DIR="/usr/share/applications"
    fi

    if [ "$NEED_SUDO" = true ] && [ ! -w "$(dirname "$INSTALL_DIR")" ]; then
        echo -e "${YELLOW}Installation to $INSTALL_DIR requires administrator privileges.${NC}"
        if [ -t 0 ]; then
            read -p "Continue with sudo installation? (y/n) " -n 1 -r; echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then echo -e "${RED}Installation cancelled.${NC}"; exit 1; fi
        fi
    fi
    
    echo -e "${YELLOW}Copying files to $INSTALL_DIR...${NC}"
    if [ "$NEED_SUDO" = true ]; then
        sudo mkdir -p "$INSTALL_DIR"
        sudo cp -r "$SOURCE_DIR"/* "$INSTALL_DIR"
        sudo chmod +x "$INSTALL_DIR/windsurf"
    else
        mkdir -p "$INSTALL_DIR"
        cp -r "$SOURCE_DIR"/* "$INSTALL_DIR"
        chmod +x "$INSTALL_DIR/windsurf"
    fi
    
    echo -e "${YELLOW}Creating symbolic link in $SYMLINK_DIR...${NC}"
    local symlink_target="$INSTALL_DIR/windsurf"
    if [ -f "$INSTALL_DIR/bin/windsurf" ]; then # Some versions might have a bin dir
        symlink_target="$INSTALL_DIR/bin/windsurf"
    fi

    if [ "$NEED_SUDO" = true ]; then
        sudo ln -sf "$symlink_target" "$SYMLINK_DIR/windsurf"
    else
        ln -sf "$symlink_target" "$SYMLINK_DIR/windsurf"
    fi
    
    echo -e "${YELLOW}Creating desktop entry...${NC}"
    local ICON_PATH=$(find "$INSTALL_DIR" -name "code.png" | head -n 1)
    if [ -z "$ICON_PATH" ]; then ICON_PATH="text-editor"; fi
    
    local DESKTOP_FILE_CONTENT="[Desktop Entry]
Name=$APP_NAME
Comment=$APP_COMMENT
Exec=$symlink_target %F
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=Windsurf
"
    
    if [ "$NEED_SUDO" = true ]; then
        echo "$DESKTOP_FILE_CONTENT" | sudo tee "$DESKTOP_DIR/windsurf.desktop" > /dev/null
    else
        echo "$DESKTOP_FILE_CONTENT" > "$DESKTOP_DIR/windsurf.desktop"
    fi
    
    if command -v update-desktop-database &> /dev/null; then
        if [ "$NEED_SUDO" = true ]; then sudo update-desktop-database "$DESKTOP_DIR"; else update-desktop-database "$DESKTOP_DIR"; fi
    fi

    # Create version file for future updates
    echo "$CURRENT_VERSION" > "$TEMP_DIR/version"
    if [ "$NEED_SUDO" = true ]; then
        sudo mv "$TEMP_DIR/version" "$INSTALL_DIR/version"
    else
        mv "$TEMP_DIR/version" "$INSTALL_DIR/version"
    fi
    
    echo -e "${GREEN}Windsurf has been successfully installed!${NC}"
}

uninstall_windsurf() {
    local user_only=false
    local clean_data=false
    
    for arg in "$@"; do
        case $arg in
            --user) user_only=true ;;
            --clean) clean_data=true ;;
        esac
    done

    echo -e "${YELLOW}Uninstalling Windsurf...${NC}"
    
    local INSTALL_DIR
    local SYMLINK_DIR
    local DESKTOP_DIR
    local NEED_SUDO=true
    
    if [ "$user_only" = true ]; then
        INSTALL_DIR="$USER_INSTALL_DIR"
        SYMLINK_DIR="$HOME/.local/bin"
        DESKTOP_DIR="$HOME/.local/share/applications"
        NEED_SUDO=false
    else
        INSTALL_DIR="$DEFAULT_INSTALL_DIR"
        SYMLINK_DIR="/usr/local/bin"
        DESKTOP_DIR="/usr/share/applications"
    fi
    
    if [ ! -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Windsurf installation not found at $INSTALL_DIR.${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Removing installation directory...${NC}"
    if [ "$NEED_SUDO" = true ]; then sudo rm -rf "$INSTALL_DIR"; else rm -rf "$INSTALL_DIR"; fi
    
    echo -e "${YELLOW}Removing symbolic link...${NC}"
    if [ -L "$SYMLINK_DIR/windsurf" ]; then
        if [ "$NEED_SUDO" = true ]; then sudo rm "$SYMLINK_DIR/windsurf"; else rm "$SYMLINK_DIR/windsurf"; fi
    fi
    
    echo -e "${YELLOW}Removing desktop entry...${NC}"
    if [ -f "$DESKTOP_DIR/windsurf.desktop" ]; then
        if [ "$NEED_SUDO" = true ]; then sudo rm "$DESKTOP_DIR/windsurf.desktop"; else rm "$DESKTOP_DIR/windsurf.desktop"; fi
        if command -v update-desktop-database &> /dev/null; then
            if [ "$NEED_SUDO" = true ]; then sudo update-desktop-database "$DESKTOP_DIR"; else update-desktop-database "$DESKTOP_DIR"; fi
        fi
    fi

    if [ "$clean_data" = true ]; then
        echo -e "${YELLOW}Removing user configuration data...${NC}"
        local USER_CONFIG_DIRS=("$HOME/.config/Windsurf" "$HOME/.windsurf")
        for dir in "${USER_CONFIG_DIRS[@]}"; do
            if [ -d "$dir" ]; then rm -rf "$dir"; fi
        done
    else
        echo -e "${BLUE}User configuration data has been preserved. Rerun with --clean to remove it.${NC}"
    fi
    
    echo -e "${GREEN}Windsurf has been successfully uninstalled!${NC}"
}

print_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  install       Install or update Windsurf (default)"
    echo "  uninstall     Uninstall Windsurf"
    echo ""
    echo "Options:"
    echo "  --user        Perform operation for current user only (no admin privileges)"
    echo "  --force       Force reinstall even if the same version is already installed"
    echo "  --clean       Remove user data and configurations during uninstall"
    echo "  --help        Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Install/update system-wide"
    echo "  $0 install --user     # Install/update for current user"
    echo "  $0 install --force    # Force reinstall latest version"
    echo "  $0 uninstall --clean  # Remove system-wide installation and user data"
}

# Main script execution
main() {
    print_header

    local ACTION="install"
    local ARGS=()

    # Simple argument parsing
    if [[ "$1" == "install" || "$1" == "update" ]]; then
        ACTION="install"
        shift
    elif [ "$1" == "uninstall" ]; then
        ACTION="uninstall"
        shift
    elif [[ "$1" == "--help" || "$1" == "-h" ]]; then
        print_usage
        exit 0
    fi
    
    ARGS=("$@")

    check_dependencies

    if [ "$ACTION" == "install" ]; then
        install_windsurf "${ARGS[@]}"
    elif [ "$ACTION" == "uninstall" ]; then
        uninstall_windsurf "${ARGS[@]}"
    fi

    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi

    exit 0
}

main "$@"
