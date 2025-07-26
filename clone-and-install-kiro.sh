#!/usr/bin/env bash

# Kiro Clone and Install Script
# This script clones the Kiro installation repo and runs the installer

set -e

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Repository information
REPO_URL="https://github.com/abhilashiig/kiro-ide-linux-installation"
TEMP_DIR="/tmp/kiro_installer_$(date +%s)"
INSTALL_SCRIPT="install-kiro.sh"

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}    Kiro Clone & Install Script      ${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo
}

cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        echo -e "${YELLOW}Cleaning up temporary files...${NC}"
        rm -rf "$TEMP_DIR"
    fi
}

# Set up cleanup on exit
trap cleanup EXIT

check_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${NC}"
    
    local deps=("git" "bash")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing required dependencies: ${missing_deps[*]}${NC}"
        echo -e "${YELLOW}Please install the missing dependencies and try again.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All dependencies satisfied.${NC}"
}

clone_repo() {
    echo -e "${YELLOW}Cloning repository to temporary directory...${NC}"
    echo -e "${BLUE}Repository: $REPO_URL${NC}"
    echo -e "${BLUE}Temporary directory: $TEMP_DIR${NC}"
    
    if ! git clone "$REPO_URL" "$TEMP_DIR"; then
        echo -e "${RED}Error: Failed to clone repository${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Repository cloned successfully.${NC}"
}

verify_install_script() {
    local script_path="$TEMP_DIR/$INSTALL_SCRIPT"
    
    echo -e "${YELLOW}Verifying installation script...${NC}"
    
    if [ ! -f "$script_path" ]; then
        echo -e "${RED}Error: Installation script not found at $script_path${NC}"
        echo -e "${YELLOW}Available files in repository:${NC}"
        ls -la "$TEMP_DIR"
        exit 1
    fi
    
    if [ ! -x "$script_path" ]; then
        echo -e "${YELLOW}Making installation script executable...${NC}"
        chmod +x "$script_path"
    fi
    
    echo -e "${GREEN}Installation script verified.${NC}"
}

run_installer() {
    local script_path="$TEMP_DIR/$INSTALL_SCRIPT"
    
    echo -e "${YELLOW}Running Kiro installation script...${NC}"
    echo -e "${BLUE}Script location: $script_path${NC}"
    
    # Check if running in pipe and no --user flag provided
    if [ ! -t 0 ] && [[ ! "$*" =~ --user ]]; then
        echo -e "${YELLOW}Note: Running via pipe (curl). For system-wide installation, sudo confirmation is required.${NC}"
        echo -e "${YELLOW}Consider using --user flag for user-only installation (no sudo required).${NC}"
        echo
    fi
    
    # Pass all arguments to the installation script
    if [ $# -gt 0 ]; then
        echo -e "${BLUE}Arguments passed to installer: $*${NC}"
        "$script_path" "$@"
    else
        "$script_path"
    fi
}

print_usage() {
    echo "Usage: $0 [INSTALLER_OPTIONS]"
    echo ""
    echo "This script clones the Kiro installation repository and runs the installer."
    echo "All arguments are passed directly to the installation script."
    echo ""
    echo "Common installer options:"
    echo "  --install     Install or update Kiro (default)"
    echo "  --update      Same as --install"
    echo "  --uninstall   Uninstall Kiro"
    echo "  --user        Perform operation for current user only (recommended for curl)"
    echo "  --force       Force reinstall even if same version exists"
    echo "  --clean       Remove user data during uninstall"
    echo "  --help        Display installer help"
    echo ""
    echo "Examples:"
    echo "  $0                    # Clone repo and install Kiro"
    echo "  $0 --user            # Clone repo and install for current user (no sudo)"
    echo "  $0 --force           # Clone repo and force reinstall"
    echo "  $0 --uninstall --user # Clone repo and uninstall user installation"
    echo ""
    echo "For curl usage:"
    echo "  curl -fsSL https://raw.githubusercontent.com/.../clone-and-install-kiro.sh | bash -s -- --user"
    echo ""
}

# Main script execution
print_header

# Check for help flag
for arg in "$@"; do
    case $arg in
        --help | -h)
            print_usage
            exit 0
            ;;
    esac
done

# Execute main workflow
check_dependencies
clone_repo
verify_install_script
run_installer "$@"

echo -e "${GREEN}Script execution completed!${NC}"