# Kiro Linux Installer Script

## What is it?

This is an installer script for [Kiro](https://kiro.dev/), an AI-powered development environment by AWS. While AWS provides `.deb` packages for Debian-based Linux distributions and a universal `.tar.gz` file for other distributions, this script simplifies the installation process for any Linux distribution, including Fedora, Arch, openSUSE, and others.

## Why was it created?

This script was created to provide a seamless installation experience for Kiro on Linux distributions that don't have native package support. It handles all the necessary steps to properly install Kiro, including:

- Checking and installing dependencies
- Setting up proper file permissions
- Creating desktop entries for easy access
- Configuring system paths
- Managing updates and uninstallation

## How to use it

### Prerequisites

1. Download the Kiro `.tar.gz` file from [https://kiro.dev/](https://kiro.dev/)
2. Extract the downloaded `.tar.gz` file
3. Place this `install-kiro.sh` script at the same level as the extracted `Kiro` folder

### Directory structure should look like:

```
some-directory/
├── Kiro/             # The extracted Kiro folder from tar.gz
└── install-kiro.sh   # This installation script
```

### Installation

```bash
# Make the script executable
chmod +x install-kiro.sh

# Run the installer
./install-kiro.sh         # For system-wide installation (requires sudo/root privileges)
# OR
./install-kiro.sh --user  # For user-only installation (no sudo required)
```

### Upgrading Kiro

When a new version of Kiro is released:

1. Download the new `.tar.gz` file from [https://kiro.dev/](https://kiro.dev/)
2. Extract it to replace the existing `Kiro` folder
3. Run the upgrade command:

```bash
./install-kiro.sh --update         # For system-wide upgrade
# OR
./install-kiro.sh --update --user  # For user-only upgrade
```

### Uninstallation

```bash
./install-kiro.sh --uninstall                # System-wide uninstall
# OR
./install-kiro.sh --uninstall --user         # User-only uninstall
# OR
./install-kiro.sh --uninstall --clean        # Complete uninstall (removes all data)
```

## Additional Options

Run `./install-kiro.sh --help` to see all available options and commands.

## Compatibility

This script works on all major Linux distributions, including but not limited to:
- Fedora
- Arch Linux
- CentOS/RHEL
- openSUSE
- Ubuntu/Debian (although native .deb packages are available)
- Other Linux distributions

## Notes on Icons/Logo

Since the Kiro package may not include the official logo, this installer script attempts to use a placeholder icon from:
```
https://img.icons8.com/nolan/64/visual-studio-code-2019.png
```

## License

This installer script is provided as-is. Kiro itself is a product of AWS and subject to its own licensing terms.
