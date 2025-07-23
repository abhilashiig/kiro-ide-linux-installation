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
FAVICON_URL="https://kiro.dev/favicon.ico"
ICON_URL="./Kiro_1024x1024x32.png"
TEMP_ICO_FILE="/tmp/kiro_favicon.ico"
TEMP_PNG_FILE="/tmp/kiro_icon.png"

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}        Kiro Installer Script        ${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo
}

check_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${NC}"
    
    # Check for basic dependencies
    DEPS=("wget" "tar" "readlink" "grep" "sed")
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
    local SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
    local KIRO_DIR="$SCRIPT_DIR/Kiro"
    
    echo -e "${YELLOW}Installing Kiro...${NC}"
    
    # Check if Kiro directory exists
    if [ ! -d "$KIRO_DIR" ]; then
        echo -e "${RED}Error: Kiro directory not found at $KIRO_DIR${NC}"
        exit 1
    fi
    
    # Determine installation method based on permissions
    local INSTALL_DIR
    local SYMLINK_DIR
    local DESKTOP_DIR
    local NEED_SUDO=true
    
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
    
    # Check write permissions
    if [ "$NEED_SUDO" = true ] && [ ! -w "$(dirname "$INSTALL_DIR")" ]; then
        echo -e "${YELLOW}Installation to $INSTALL_DIR requires administrator privileges.${NC}"
        echo -e "${YELLOW}Use --user flag to install to $USER_INSTALL_DIR instead.${NC}"
        
        # Ask for confirmation
        read -p "Continue with sudo installation? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Installation cancelled.${NC}"
            exit 1
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
        # Download favicon as icon
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
    
    echo -e "${GREEN}Kiro has been successfully installed!${NC}"
}

update_kiro() {
    echo -e "${YELLOW}Updating Kiro...${NC}"
    
    local SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
    local KIRO_DIR="$SCRIPT_DIR/Kiro"
    local INSTALL_DIR
    local SYMLINK_DIR
    local DESKTOP_DIR
    local NEED_SUDO=true
    local CONFIG_BACKUP_DIR="/tmp/kiro_config_backup_$(date +%s)"
    
    # Check if Kiro directory exists
    if [ ! -d "$KIRO_DIR" ]; then
        echo -e "${RED}Error: Kiro update package not found at $KIRO_DIR${NC}"
        exit 1
    fi
    
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
    
    # Check if installation exists
    if [ ! -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Kiro is not installed at $INSTALL_DIR.${NC}"
        
        # Check alternative installation
        if [ "$1" == "--user" ] && [ -d "$DEFAULT_INSTALL_DIR" ]; then
            echo -e "${YELLOW}Kiro might be installed at $DEFAULT_INSTALL_DIR. Use the script without the --user flag to update.${NC}"
        elif [ "$1" != "--user" ] && [ -d "$USER_INSTALL_DIR" ]; then
            echo -e "${YELLOW}Kiro might be installed at $USER_INSTALL_DIR. Use the --user flag to update.${NC}"
        else
            echo -e "${RED}Kiro installation not found. Please use --install instead.${NC}"
            exit 1
        fi
        
        return 1
    fi
    
    # Check write permissions
    if [ "$NEED_SUDO" = true ] && [ ! -w "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Updating Kiro at $INSTALL_DIR requires administrator privileges.${NC}"
        
        # Ask for confirmation
        read -p "Continue with sudo update? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Update cancelled.${NC}"
            exit 1
        fi
    fi
    
    # Backup user configurations
    echo -e "${YELLOW}Backing up user configurations...${NC}"
    mkdir -p "$CONFIG_BACKUP_DIR"
    
    # Locate user data directory
    local USER_DATA_DIRS=("$HOME/.config/kiro" "$HOME/.kiro")
    for dir in "${USER_DATA_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "${YELLOW}Backing up $dir...${NC}"
            cp -r "$dir" "$CONFIG_BACKUP_DIR/"
        fi
    done
    
    # Update Kiro files
    echo -e "${YELLOW}Updating Kiro to new version...${NC}"
    if [ "$NEED_SUDO" = true ]; then
        # Preserve executable permissions on important files
        sudo rm -rf "$INSTALL_DIR"
        sudo mkdir -p "$INSTALL_DIR"
        sudo cp -r "$KIRO_DIR"/* "$INSTALL_DIR"
    else
        rm -rf "$INSTALL_DIR"
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
    
    # Update symbolic link
    echo -e "${YELLOW}Updating symbolic link...${NC}"
    if [ "$NEED_SUDO" = true ]; then
        sudo ln -sf "$INSTALL_DIR/bin/kiro" "$SYMLINK_DIR/kiro"
    else
        ln -sf "$INSTALL_DIR/bin/kiro" "$SYMLINK_DIR/kiro"
    fi
    
    # Update desktop file
    echo -e "${YELLOW}Updating desktop entry...${NC}"
    
    # Find icon path
    local ICON_PATH
    if [ -f "$INSTALL_DIR/resources/app/resources/linux/kiro.png" ]; then
        ICON_PATH="$INSTALL_DIR/resources/app/resources/linux/kiro.png"
    elif [ -f "$INSTALL_DIR/resources/app/resources/app.png" ]; then
        ICON_PATH="$INSTALL_DIR/resources/app/resources/app.png"
    else
        # Download favicon as icon
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
    
    echo -e "${GREEN}Kiro has been successfully updated!${NC}"
    echo -e "${YELLOW}A backup of your configurations was created at $CONFIG_BACKUP_DIR${NC}"
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
    echo "Usage: $0 [OPTION]"
    echo "Install, update, or uninstall Kiro."
    echo
    echo "Options:"
    echo "  --install        Install Kiro (default)"
    echo "  --update         Update an existing Kiro installation"
    echo "  --uninstall      Uninstall Kiro"
    echo "  --user           Install/update/uninstall for current user only"
    echo "  --clean          Remove all user configuration data during uninstallation"
    echo "  --help           Display this help and exit"
    echo
}

download_favicon() {
    local target_dir="$1"
    local need_sudo="$2"
    local icon_dir
    local temp_png="$TEMP_PNG_FILE"
    local success=false
    
    # Create target directory
    if [ "$need_sudo" = true ]; then
        icon_dir="$target_dir/resources/app/resources/linux"
        echo -e "${YELLOW}Downloading icon for Kiro...${NC}"
        sudo mkdir -p "$icon_dir"
    else
        icon_dir="$target_dir/resources/app/resources/linux"
        echo -e "${YELLOW}Downloading icon for Kiro...${NC}"
        mkdir -p "$icon_dir"
    fi
    
    # Download the icon directly as PNG
    if command -v wget &> /dev/null; then
        wget -q "$ICON_URL" -O "$temp_png" && success=true
    elif command -v curl &> /dev/null; then
        curl -s "$ICON_URL" -o "$temp_png" && success=true
    else
        echo -e "${YELLOW}Warning: Could not download icon. Neither wget nor curl is available.${NC}"
    fi
    
    if [ "$success" = true ]; then
        # Copy the downloaded PNG to the installation directory
        if [ "$need_sudo" = true ]; then
            sudo cp "$temp_png" "$icon_dir/kiro.png" && \
            echo -e "${GREEN}Successfully downloaded and installed icon.${NC}" && \
            rm -f "$temp_png" && \
            return 0
        else
            cp "$temp_png" "$icon_dir/kiro.png" && \
            echo -e "${GREEN}Successfully downloaded and installed icon.${NC}" && \
            rm -f "$temp_png" && \
            return 0
        fi
    fi
    
    # If we failed to get the icon, try using a system fallback icon
    echo -e "${YELLOW}Failed to download icon. Attempting to use system fallback icon...${NC}"
    
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
CLEAN_UNINSTALL=false

for arg in "$@"; do
    case $arg in
        --install)
            ACTION="install"
            shift
            ;;
        --update)
            ACTION="update"
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
    if [ "$USER_ONLY" = true ]; then
        install_kiro "--user"
    else
        install_kiro
    fi
elif [ "$ACTION" == "update" ]; then
    check_dependencies
    if [ "$USER_ONLY" = true ]; then
        update_kiro "--user"
    else
        update_kiro
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

exit 0
