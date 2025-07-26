#!/usr/bin/env bash

# Kiro Installer Script
# This script installs Kiro on any Linux distribution

set -e

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default installation directory
DEFAULT_INSTALL_DIR="/opt/kiro"
USER_INSTALL_DIR="$HOME/.local/share/kiro"

# Application information
APP_NAME="Kiro"
APP_COMMENT="Kiro - AI-powered development environment"
APP_EXEC="/opt/kiro/bin/kiro"
APP_ICON="/opt/kiro/resources/app/resources/linux/kiro.png"
USER_APP_ICON="$HOME/.local/share/kiro/resources/app/resources/linux/kiro.png"
ICON_URL="./Kiro_1024x1024x32.png"
TEMP_PNG_FILE="/tmp/kiro_icon.png"

# Metadata and download URLs
METADATA_URL="https://prod.download.desktop.kiro.dev/stable/metadata-linux-x64-stable.json"
TEMP_DIR="/tmp/kiro_install_$(date +%s)"
TEMP_METADATA_FILE="$TEMP_DIR/metadata.json"
TEMP_ARCHIVE_FILE="$TEMP_DIR/kiro.tar.gz"

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}        Kiro Installer Script        ${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo
}

# Function to fetch metadata and latest version information
fetch_metadata() {
    echo -e "${YELLOW}Fetching latest Kiro metadata...${NC}"
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Download metadata file
    if ! curl -s "$METADATA_URL" -o "$TEMP_METADATA_FILE"; then
        echo -e "${RED}Error: Failed to download metadata from $METADATA_URL${NC}"
        return 1
    fi
    
    # Check if the metadata file was downloaded successfully
    if [ ! -s "$TEMP_METADATA_FILE" ]; then
        echo -e "${RED}Error: Downloaded metadata file is empty${NC}"
        return 1
    fi
    
    # Parse current version
    CURRENT_VERSION=$(jq -r '.currentRelease' "$TEMP_METADATA_FILE")
    if [ -z "$CURRENT_VERSION" ] || [ "$CURRENT_VERSION" == "null" ]; then
        echo -e "${RED}Error: Could not determine current version from metadata${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Latest version available: $CURRENT_VERSION${NC}"
    return 0
}

# Function to get the currently installed Kiro version
get_installed_version() {
    local install_dir="$1"
    local installed_version=""
    
    # Check if Kiro is installed
    if [ ! -d "$install_dir" ]; then
        echo ""
        return 1
    fi
    
    # Try to get version from the executable using -v flag (Kiro specific)
    if [ -f "$install_dir/bin/kiro" ]; then
        installed_version=$("$install_dir/bin/kiro" -v 2>/dev/null | head -n 1 | tr -d ' \n\r')
        # Validate version format (should be like 0.1.15)
        if [[ ! "$installed_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            installed_version=""
        fi
    fi
    
    # If that fails, try the main executable
    if [ -z "$installed_version" ] && [ -f "$install_dir/kiro" ]; then
        installed_version=$("$install_dir/kiro" -v 2>/dev/null | head -n 1 | tr -d ' \n\r')
        # Validate version format (should be like 0.1.15)
        if [[ ! "$installed_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            installed_version=""
        fi
    fi
    
    # Also try --version as fallback
    if [ -z "$installed_version" ] && [ -f "$install_dir/bin/kiro" ]; then
        installed_version=$("$install_dir/bin/kiro" --version 2>/dev/null | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    fi
    
    if [ -z "$installed_version" ] && [ -f "$install_dir/kiro" ]; then
        installed_version=$("$install_dir/kiro" --version 2>/dev/null | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    fi
    
    # Try to find version in package.json or version files
    if [ -z "$installed_version" ]; then
        local version_files=(
            "$install_dir/resources/app/package.json"
            "$install_dir/resources/package.json" 
            "$install_dir/package.json"
            "$install_dir/version"
            "$install_dir/VERSION"
        )
        
        for version_file in "${version_files[@]}"; do
            if [ -f "$version_file" ]; then
                if [[ "$version_file" == *.json ]]; then
                    # Extract version from JSON file
                    installed_version=$(jq -r '.version // empty' "$version_file" 2>/dev/null)
                else
                    # Read version from plain text file
                    installed_version=$(cat "$version_file" 2>/dev/null | head -n 1 | tr -d ' \n\r')
                fi
                
                # Validate version format
                if [[ "$installed_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
                    break
                else
                    installed_version=""
                fi
            fi
        done
    fi
    
    echo "$installed_version"
    return 0
}

# Function to compare version strings (returns 0 if v1 >= v2, 1 if v1 < v2)
version_compare() {
    local v1="$1"
    local v2="$2"
    
    # Handle empty versions
    if [ -z "$v1" ]; then
        return 1  # No version installed, update needed
    fi
    if [ -z "$v2" ]; then
        return 0  # No remote version, don't update
    fi
    
    # Compare versions using sort -V (version sort)
    if printf '%s\n%s\n' "$v1" "$v2" | sort -V -C 2>/dev/null; then
        # v1 <= v2, check if they're equal
        if [ "$v1" = "$v2" ]; then
            return 0  # Same version
        else
            return 1  # v1 < v2, update needed
        fi
    else
        return 0  # v1 > v2, no update needed
    fi
}

# Function to check if update is needed
check_update_needed() {
    local install_dir="$1"
    local force_update="${2:-false}"
    
    # If force update is requested, always update
    if [ "$force_update" = true ]; then
        echo -e "${YELLOW}Force update requested, skipping version check.${NC}"
        return 0
    fi
    
    # Get installed version
    local installed_version
    installed_version=$(get_installed_version "$install_dir")
    
    if [ -z "$installed_version" ]; then
        echo -e "${YELLOW}No existing Kiro installation found. Proceeding with fresh installation.${NC}"
        return 0  # Fresh install needed
    fi
    
    echo -e "${BLUE}Currently installed version: $installed_version${NC}"
    
    # Fetch latest version if not already done
    if [ -z "$CURRENT_VERSION" ]; then
        if ! fetch_metadata; then
            echo -e "${RED}Error: Could not fetch latest version information.${NC}"
            return 1
        fi
    fi
    
    # Compare versions
    if version_compare "$installed_version" "$CURRENT_VERSION"; then
        echo -e "${GREEN}Kiro is already up to date (version $installed_version).${NC}"
        echo -e "${BLUE}Use --force flag to reinstall anyway.${NC}"
        return 1  # No update needed
    else
        echo -e "${YELLOW}Update available: $installed_version → $CURRENT_VERSION${NC}"
        return 0  # Update needed
    fi
}

# Function to download Kiro package and verification files
download_kiro_package() {
    echo -e "${YELLOW}Downloading Kiro package...${NC}"
    
    # Extract download URL for package
    local PACKAGE_URL=$(jq -r '.releases[] | select(.updateTo.url | endswith(".tar.gz")) | .updateTo.url' "$TEMP_METADATA_FILE")
    
    # Download package
    echo -e "${YELLOW}Downloading from: $PACKAGE_URL${NC}"
    if ! curl -L "$PACKAGE_URL" -o "$TEMP_ARCHIVE_FILE"; then
        echo -e "${RED}Error: Failed to download Kiro package${NC}"
        return 1
    fi
    
    # Extract to temporary location
    echo -e "${YELLOW}Extracting Kiro package...${NC}"
    mkdir -p "$TEMP_DIR/extracted"
    if ! tar -xzf "$TEMP_ARCHIVE_FILE" -C "$TEMP_DIR/extracted"; then
        echo -e "${RED}Error: Failed to extract Kiro package${NC}"
        return 1
    fi
    
    # Find the extracted directory name (should be something like 202507152342-distro-linux-x64)
    local EXTRACTED_DIR=$(find "$TEMP_DIR/extracted" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    
    # Check if the expected structure exists
    if [ -d "$EXTRACTED_DIR/Kiro" ]; then
        echo -e "${GREEN}Found Kiro directory in extracted package.${NC}"
        # Move the Kiro directory up to our expected location
        mv "$EXTRACTED_DIR/Kiro" "$TEMP_DIR/extracted/Kiro"
        # Remove the now-empty parent directory
        rmdir "$EXTRACTED_DIR" 2>/dev/null || true
    else
        echo -e "${YELLOW}Warning: Did not find expected directory structure. Continuing anyway.${NC}"
    fi
    
    return 0
}

check_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${NC}"
    
    # Check for basic dependencies
    DEPS=("wget" "tar" "readlink" "grep" "sed" "curl" "jq")
    MISSING_DEPS=()
    
    for dep in "${DEPS[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            MISSING_DEPS+=("$dep")
        fi
    done
    
    # Optional dependencies for desktop integration
    if [ ! -d "$HOME/.local/share/applications" ] && [ ! -d "/usr/share/applications" ]; then
        echo -e "${YELLOW}Warning: Could not find applications directory. Desktop integration might not work.${NC}"
    fi
    
    # If missing dependencies, try to install them
    if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
        echo -e "${YELLOW}The following dependencies are missing: ${MISSING_DEPS[*]}${NC}"
        
        # Try to detect package manager and install dependencies
        if command -v apt &> /dev/null; then
            echo -e "${YELLOW}Detected apt package manager. Attempting to install dependencies...${NC}"
            sudo apt update && sudo apt install -y "${MISSING_DEPS[@]}"
        elif command -v dnf &> /dev/null; then
            echo -e "${YELLOW}Detected dnf package manager. Attempting to install dependencies...${NC}"
            sudo dnf install -y "${MISSING_DEPS[@]}"
        elif command -v yum &> /dev/null; then
            echo -e "${YELLOW}Detected yum package manager. Attempting to install dependencies...${NC}"
            sudo yum install -y "${MISSING_DEPS[@]}"
        elif command -v pacman &> /dev/null; then
            echo -e "${YELLOW}Detected pacman package manager. Attempting to install dependencies...${NC}"
            sudo pacman -Sy --needed "${MISSING_DEPS[@]}"
        elif command -v zypper &> /dev/null; then
            echo -e "${YELLOW}Detected zypper package manager. Attempting to install dependencies...${NC}"
            sudo zypper install -y "${MISSING_DEPS[@]}"
        else
            echo -e "${RED}Could not detect package manager. Please install the following dependencies manually: ${MISSING_DEPS[*]}${NC}"
            exit 1
        fi
        
        # Check if dependencies are now installed
        for dep in "${MISSING_DEPS[@]}"; do
            if ! command -v "$dep" &> /dev/null; then
                echo -e "${RED}Failed to install $dep. Please install it manually.${NC}"
                exit 1
            fi
        done
    fi
    
    echo -e "${GREEN}All dependencies are satisfied.${NC}"
}

install_kiro() {
    echo -e "${YELLOW}Installing/Updating Kiro...${NC}"
    
    # Determine installation directory based on user flag
    local INSTALL_DIR
    local FORCE_UPDATE=false
    
    if [ "$1" == "--user" ]; then
        INSTALL_DIR="$USER_INSTALL_DIR"
    elif [ "$1" == "--force" ]; then
        INSTALL_DIR="$DEFAULT_INSTALL_DIR"
        FORCE_UPDATE=true
    elif [ "$1" == "--user" ] && [ "$2" == "--force" ]; then
        INSTALL_DIR="$USER_INSTALL_DIR"
        FORCE_UPDATE=true
    elif [ "$2" == "--force" ]; then
        INSTALL_DIR="$DEFAULT_INSTALL_DIR"
        FORCE_UPDATE=true
    else
        INSTALL_DIR="$DEFAULT_INSTALL_DIR"
    fi
    
    # First fetch metadata to get latest version
    if ! fetch_metadata; then
        echo -e "${RED}Error: Could not fetch Kiro metadata.${NC}"
        exit 1
    fi
    
    # Check if update is needed
    if ! check_update_needed "$INSTALL_DIR" "$FORCE_UPDATE"; then
        # No update needed, exit gracefully
        return 0
    fi
    
    # Download package only if update is needed
    if ! download_kiro_package; then
        echo -e "${RED}Error: Could not download Kiro package.${NC}"
        exit 1
    fi
    
    # Extracted files location
    local KIRO_DIR="$TEMP_DIR/extracted"
    
    # Check if the Kiro directory exists in the extracted files
    if [ -d "$KIRO_DIR/Kiro" ]; then
        KIRO_DIR="$KIRO_DIR/Kiro"
    fi
    
    # Check if the extracted directory is valid
    if [ ! -d "$KIRO_DIR" ]; then
        echo -e "${RED}Error: Invalid Kiro package extracted. Could not find Kiro directory.${NC}"
        echo -e "${YELLOW}Contents found instead:${NC}"
        find "$TEMP_DIR/extracted" -type f -o -type d | sort | head -n 20
        exit 1
    fi
    
    # Check for binary files
    if [ ! -f "$KIRO_DIR/kiro" ] && [ ! -f "$KIRO_DIR/bin/kiro" ]; then
        echo -e "${RED}Error: Invalid Kiro package extracted. Missing required executable files.${NC}"
        echo -e "${YELLOW}Contents found instead in $KIRO_DIR:${NC}"
        find "$KIRO_DIR" -maxdepth 2 -type f -o -type d | sort | head -n 20
        exit 1
    fi
    
    # Check for existing installation and back up configurations if needed
    local CONFIG_BACKUP_DIR=""
    local INSTALL_DIR
    local SYMLINK_DIR
    local DESKTOP_DIR
    local NEED_SUDO=true
    
    # Determine installation directories based on user flag
    if [ "$1" == "--user" ]; then
        INSTALL_DIR="$USER_INSTALL_DIR"
        SYMLINK_DIR="$HOME/.local/bin"
        DESKTOP_DIR="$HOME/.local/share/applications"
        NEED_SUDO=false
        APP_EXEC="$USER_INSTALL_DIR/bin/kiro"
        APP_ICON="$USER_INSTALL_DIR/resources/app/resources/linux/kiro.png"
        
        # Create directories if they don't exist
        mkdir -p "$SYMLINK_DIR"
        mkdir -p "$DESKTOP_DIR"
    else
        INSTALL_DIR="$DEFAULT_INSTALL_DIR"
        SYMLINK_DIR="/usr/local/bin"
        DESKTOP_DIR="/usr/share/applications"
    fi
    
    # Check if this is an update
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Detected existing Kiro installation. Updating...${NC}"
        
        # Backup user configurations
        CONFIG_BACKUP_DIR="/tmp/kiro_config_backup_$(date +%s)"
        echo -e "${YELLOW}Backing up user configurations to $CONFIG_BACKUP_DIR...${NC}"
        mkdir -p "$CONFIG_BACKUP_DIR"
        
        # Locate user data directory
        local USER_DATA_DIRS=("$HOME/.config/kiro" "$HOME/.kiro")
        for dir in "${USER_DATA_DIRS[@]}"; do
            if [ -d "$dir" ]; then
                echo -e "${YELLOW}Backing up $dir...${NC}"
                cp -r "$dir" "$CONFIG_BACKUP_DIR/"
            fi
        done
    fi
    
    # Check write permissions and handle confirmation
    if [ "$NEED_SUDO" = true ] && [ ! -w "$(dirname "$INSTALL_DIR")" ]; then
        echo -e "${YELLOW}Installation to $INSTALL_DIR requires administrator privileges.${NC}"
        
        # Check if we're running in a pipe (like from curl) or interactive terminal
        if [ -t 0 ]; then
            # Interactive terminal - ask for confirmation
            echo -e "${YELLOW}Use --user flag to install to $USER_INSTALL_DIR instead.${NC}"
            read -p "Continue with sudo installation? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${RED}Installation cancelled.${NC}"
                exit 1
            fi
        else
            # Running in pipe - proceed with sudo but warn user
            echo -e "${YELLOW}Running in non-interactive mode. Proceeding with sudo installation.${NC}"
            echo -e "${BLUE}You will be prompted for your password by sudo.${NC}"
        fi
    fi
    
    # Copy files
    echo -e "${YELLOW}Copying files to $INSTALL_DIR...${NC}"
    if [ "$NEED_SUDO" = true ]; then
        sudo mkdir -p "$INSTALL_DIR"
        sudo cp -r "$KIRO_DIR"/* "$INSTALL_DIR"
    else
        mkdir -p "$INSTALL_DIR"
        cp -r "$KIRO_DIR"/* "$INSTALL_DIR"
    fi
    
    # Set executable permissions
    echo -e "${YELLOW}Setting permissions...${NC}"
    if [ "$NEED_SUDO" = true ]; then
        sudo chmod +x "$INSTALL_DIR/kiro"
        sudo chmod +x "$INSTALL_DIR/bin/kiro"
        sudo chmod +x "$INSTALL_DIR/chrome-sandbox"
        sudo chmod 4755 "$INSTALL_DIR/chrome-sandbox"
    else
        chmod +x "$INSTALL_DIR/kiro"
        chmod +x "$INSTALL_DIR/bin/kiro"
        chmod +x "$INSTALL_DIR/chrome-sandbox"
        chmod 4755 "$INSTALL_DIR/chrome-sandbox"
    fi
    
    # Create symbolic link
    echo -e "${YELLOW}Creating symbolic link in $SYMLINK_DIR...${NC}"
    if [ "$NEED_SUDO" = true ]; then
        sudo ln -sf "$INSTALL_DIR/bin/kiro" "$SYMLINK_DIR/kiro"
    else
        ln -sf "$INSTALL_DIR/bin/kiro" "$SYMLINK_DIR/kiro"
    fi
    
    # Create desktop file for application menu integration
    echo -e "${YELLOW}Creating desktop entry...${NC}"
    
    # Find icon path - search for the icon in resources
    local ICON_PATH
    if [ -f "$INSTALL_DIR/resources/app/resources/linux/kiro.png" ]; then
        ICON_PATH="$INSTALL_DIR/resources/app/resources/linux/kiro.png"
    elif [ -f "$INSTALL_DIR/resources/app/resources/app.png" ]; then
        ICON_PATH="$INSTALL_DIR/resources/app/resources/app.png"
    else
        # Install local Kiro icon
        download_favicon "$INSTALL_DIR" "$NEED_SUDO"
        ICON_PATH="$INSTALL_DIR/resources/app/resources/linux/kiro.png"
    fi
    
    # Create desktop file content
    local DESKTOP_FILE_CONTENT="[Desktop Entry]
Name=Kiro
Comment=$APP_COMMENT
Exec=$INSTALL_DIR/bin/kiro %F
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Development;IDE;
MimeType=text/plain;inode/directory;
StartupWMClass=kiro
StartupNotify=true
"

    # Write desktop file
    if [ "$NEED_SUDO" = true ]; then
        echo "$DESKTOP_FILE_CONTENT" | sudo tee "$DESKTOP_DIR/kiro.desktop" > /dev/null
        sudo chmod +x "$DESKTOP_DIR/kiro.desktop"
    else
        echo "$DESKTOP_FILE_CONTENT" > "$DESKTOP_DIR/kiro.desktop"
        chmod +x "$DESKTOP_DIR/kiro.desktop"
    fi
    
    # Update desktop database if command exists
    if command -v update-desktop-database &> /dev/null; then
        if [ "$NEED_SUDO" = true ]; then
            sudo update-desktop-database "$DESKTOP_DIR"
        else
            update-desktop-database "$DESKTOP_DIR"
        fi
    fi
    
    # Show completion message
    echo -e "${GREEN}Kiro has been successfully installed!${NC}"
    
    # If this was an update and we backed up configurations, show the backup message
    if [ -n "$CONFIG_BACKUP_DIR" ]; then
        echo -e "${YELLOW}A backup of your configurations was created at $CONFIG_BACKUP_DIR${NC}"
    fi
}

uninstall_kiro() {
    echo -e "${YELLOW}Uninstalling Kiro...${NC}"
    
    local INSTALL_DIR
    local SYMLINK_DIR
    local DESKTOP_DIR
    local NEED_SUDO=true
    local CLEAN_USER_DATA=false
    
    if [ "$1" == "--user" ]; then
        INSTALL_DIR="$USER_INSTALL_DIR"
        SYMLINK_DIR="$HOME/.local/bin"
        DESKTOP_DIR="$HOME/.local/share/applications"
        NEED_SUDO=false
    else
        INSTALL_DIR="$DEFAULT_INSTALL_DIR"
        SYMLINK_DIR="/usr/local/bin"
        DESKTOP_DIR="/usr/share/applications"
    fi

    # Check if a clean removal was requested
    if [ "$2" == "--clean" ]; then
        CLEAN_USER_DATA=true
        echo -e "${YELLOW}Clean removal requested. User configuration will also be removed.${NC}"
    fi
    
    # Check if installation exists
    if [ ! -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Kiro is not installed at $INSTALL_DIR.${NC}"
        
        # Check alternative installation
        if [ "$1" == "--user" ] && [ -d "$DEFAULT_INSTALL_DIR" ]; then
            echo -e "${YELLOW}Kiro might be installed at $DEFAULT_INSTALL_DIR. Use the script without the --user flag to uninstall.${NC}"
        elif [ "$1" != "--user" ] && [ -d "$USER_INSTALL_DIR" ]; then
            echo -e "${YELLOW}Kiro might be installed at $USER_INSTALL_DIR. Use the --user flag to uninstall.${NC}"
        else
            echo -e "${RED}Kiro installation not found.${NC}"
        fi
        
        return 1
    fi
    
    # Remove installation directory
    echo -e "${YELLOW}Removing installation directory...${NC}"
    if [ "$NEED_SUDO" = true ]; then
        sudo rm -rf "$INSTALL_DIR"
    else
        rm -rf "$INSTALL_DIR"
    fi
    
    # Remove symbolic link
    echo -e "${YELLOW}Removing symbolic link...${NC}"
    if [ -L "$SYMLINK_DIR/kiro" ]; then
        if [ "$NEED_SUDO" = true ]; then
            sudo rm "$SYMLINK_DIR/kiro"
        else
            rm "$SYMLINK_DIR/kiro"
        fi
    fi
    
    # Remove desktop file
    echo -e "${YELLOW}Removing desktop entry...${NC}"
    if [ -f "$DESKTOP_DIR/kiro.desktop" ]; then
        if [ "$NEED_SUDO" = true ]; then
            sudo rm "$DESKTOP_DIR/kiro.desktop"
        else
            rm "$DESKTOP_DIR/kiro.desktop"
        fi
        
        # Update desktop database if command exists
        if command -v update-desktop-database &> /dev/null; then
            if [ "$NEED_SUDO" = true ]; then
                sudo update-desktop-database "$DESKTOP_DIR"
            else
                update-desktop-database "$DESKTOP_DIR"
            fi
        fi
    fi

    # Remove user configuration data if clean removal was requested
    if [ "$CLEAN_USER_DATA" = true ]; then
        echo -e "${YELLOW}Removing user configuration data...${NC}"
        
        # Common locations for user configuration data
        local USER_CONFIG_DIRS=(
            "$HOME/.config/kiro"
            "$HOME/.kiro"
            "$HOME/.local/state/kiro"
            "$HOME/.local/share/kiro-extensions"
            "$HOME/.cache/kiro"
            "$HOME/.vscode-kiro"
        )
        
        for dir in "${USER_CONFIG_DIRS[@]}"; do
            if [ -d "$dir" ]; then
                echo -e "${YELLOW}Removing $dir${NC}"
                rm -rf "$dir"
            fi
        done
        
        echo -e "${GREEN}All user configuration data has been removed.${NC}"
    else
        echo -e "${BLUE}Note: User configuration data has been preserved.${NC}"
        echo -e "${BLUE}To remove user data, rerun with the --clean flag.${NC}"
    fi
    
    echo -e "${GREEN}Kiro has been successfully uninstalled!${NC}"
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --install     Install or update Kiro (default)"
    echo "  --update      Same as --install, will install or update automatically"
    echo "  --uninstall   Uninstall Kiro"
    echo "  --user        Perform operation for current user only (no admin privileges required)"
    echo "  --force       Force reinstall even if the same version is already installed"
    echo "  --clean       Remove user data and configurations during uninstall"
    echo "  --help        Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Install/update Kiro system-wide"
    echo "  $0 --user            # Install/update Kiro for current user only"
    echo "  $0 --force           # Force reinstall latest version"
    echo "  $0 --user --force    # Force reinstall for current user"
    echo "  $0 --uninstall       # Remove system-wide installation"
    echo "  $0 --uninstall --user --clean  # Remove user installation and data"
    echo ""
}

download_favicon() {
    local target_dir="$1"
    local need_sudo="$2"
    local icon_dir
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local local_icon="$script_dir/Kiro_1024x1024x32.png"
    
    # Create target directory
    if [ "$need_sudo" = true ]; then
        icon_dir="$target_dir/resources/app/resources/linux"
        echo -e "${YELLOW}Installing Kiro icon...${NC}"
        sudo mkdir -p "$icon_dir"
    else
        icon_dir="$target_dir/resources/app/resources/linux"
        echo -e "${YELLOW}Installing Kiro icon...${NC}"
        mkdir -p "$icon_dir"
    fi
    
    # Use the local PNG file
    if [ -f "$local_icon" ]; then
        if [ "$need_sudo" = true ]; then
            sudo cp "$local_icon" "$icon_dir/kiro.png" && \
            echo -e "${GREEN}Successfully installed Kiro icon.${NC}" && \
            return 0
        else
            cp "$local_icon" "$icon_dir/kiro.png" && \
            echo -e "${GREEN}Successfully installed Kiro icon.${NC}" && \
            return 0
        fi
    else
        echo -e "${YELLOW}Warning: Local Kiro icon not found at $local_icon${NC}"
    fi
    
    # If we can't find the local icon, try using a system fallback icon
    echo -e "${YELLOW}Attempting to use system fallback icon...${NC}"
    
    # Try common system icons for code editors
    local system_icons=(
        "/usr/share/icons/hicolor/128x128/apps/code.png"
        "/usr/share/icons/hicolor/128x128/apps/visual-studio-code.png"
        "/usr/share/icons/hicolor/128x128/apps/com.visualstudio.code.png"
        "/usr/share/icons/hicolor/scalable/apps/text-editor.svg"
        "/usr/share/icons/hicolor/128x128/apps/accessories-text-editor.png"
    )
    
    for icon in "${system_icons[@]}"; do
        if [ -f "$icon" ]; then
            if [ "$need_sudo" = true ]; then
                sudo cp "$icon" "$icon_dir/kiro.png" && \
                echo -e "${GREEN}Using system icon: $icon${NC}" && \
                return 0
            else
                cp "$icon" "$icon_dir/kiro.png" && \
                echo -e "${GREEN}Using system icon: $icon${NC}" && \
                return 0
            fi
        fi
    done
    
    echo -e "${YELLOW}Warning: Could not find suitable icon.${NC}"
    return 1
}

# Main script execution
print_header

# Parse command line arguments
ACTION="install"
USER_ONLY=false
FORCE_UPDATE=false
CLEAN_UNINSTALL=false

for arg in "$@"; do
    case $arg in
        --install | --update)
            ACTION="install"  # Both install and update use the same function now
            shift
            ;;
        --uninstall)
            ACTION="uninstall"
            shift
            ;;
        --user)
            USER_ONLY=true
            shift
            ;;
        --force)
            FORCE_UPDATE=true
            shift
            ;;
        --clean)
            CLEAN_UNINSTALL=true
            shift
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            print_usage
            exit 1
            ;;
    esac
done

# Execute the selected action
if [ "$ACTION" == "install" ]; then
    check_dependencies
    if [ "$USER_ONLY" = true ] && [ "$FORCE_UPDATE" = true ]; then
        install_kiro "--user" "--force"
    elif [ "$USER_ONLY" = true ]; then
        install_kiro "--user"
    elif [ "$FORCE_UPDATE" = true ]; then
        install_kiro "--force"
    else
        install_kiro
    fi
elif [ "$ACTION" == "uninstall" ]; then
    if [ "$USER_ONLY" = true ]; then
        if [ "$CLEAN_UNINSTALL" = true ]; then
            uninstall_kiro "--user" "--clean"
        else
            uninstall_kiro "--user"
        fi
    else
        if [ "$CLEAN_UNINSTALL" = true ]; then
            uninstall_kiro "" "--clean"
        else
            uninstall_kiro
        fi
    fi
fi

# Clean up temporary files
if [ -d "$TEMP_DIR" ]; then
    echo -e "${YELLOW}Cleaning up temporary files...${NC}"
    rm -rf "$TEMP_DIR"
fi

exit 0
