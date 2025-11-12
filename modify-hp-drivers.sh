#!/bin/bash

# HP Printer Drivers Modifier for macOS
# This script automatically downloads, modifies, and repackages HP printer drivers
# to remove macOS version restrictions.

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DMG_URL="https://ftp.hp.com/pub/softlib/software12/HP_Quick_Start/osx/Applications/ASU/HewlettPackardPrinterDrivers.dmg"
DMG_FILE="HewlettPackardPrinterDrivers.dmg"
PKG_FILE="HewlettPackardPrinterDrivers.pkg"
MODIFIED_PKG="HewlettPackardPrinterDrivers-modified.pkg"
EXTRACTED_DIR="extracted"
MOUNT_POINT="/Volumes/HP Easy Start"

# Functions
print_step() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
    exit 1
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

cleanup() {
    print_step "Cleaning up temporary files..."

    # Unmount DMG if mounted
    if [ -d "$MOUNT_POINT" ]; then
        hdiutil detach "$MOUNT_POINT" 2>/dev/null || true
    fi

    # Remove extracted directory
    if [ -d "$EXTRACTED_DIR" ]; then
        rm -rf "$EXTRACTED_DIR"
    fi

    # Remove downloaded DMG
    if [ -f "$DMG_FILE" ]; then
        rm -f "$DMG_FILE"
    fi
}

# Trap to cleanup on exit
trap cleanup EXIT

# Main script
echo "======================================"
echo "HP Printer Drivers Modifier for macOS"
echo "======================================"
echo

# Step 1: Download DMG
if [ -f "$PKG_FILE" ]; then
    print_warning "Package file already exists. Skipping download."
else
    print_step "Downloading HP printer drivers..."
    curl -L -o "$DMG_FILE" "$DMG_URL" || print_error "Failed to download DMG file"

    # Step 2: Mount DMG
    print_step "Mounting DMG..."
    hdiutil attach "$DMG_FILE" -quiet || print_error "Failed to mount DMG"

    # Step 3: Copy PKG from DMG
    print_step "Extracting package from DMG..."
    if [ -f "$MOUNT_POINT/$PKG_FILE" ]; then
        cp "$MOUNT_POINT/$PKG_FILE" . || print_error "Failed to copy package"
    else
        print_error "Package not found in DMG"
    fi

    # Step 4: Unmount DMG
    print_step "Unmounting DMG..."
    hdiutil detach "$MOUNT_POINT" -quiet || print_warning "Failed to unmount DMG"

    # Remove DMG file
    rm -f "$DMG_FILE"
fi

# Step 5: Extract package
print_step "Extracting package contents..."
pkgutil --expand "$PKG_FILE" "$EXTRACTED_DIR" || print_error "Failed to extract package"

# Step 6: Modify Distribution file
print_step "Modifying version restrictions..."
DISTRIBUTION_FILE="$EXTRACTED_DIR/Distribution"

if [ ! -f "$DISTRIBUTION_FILE" ]; then
    print_error "Distribution file not found"
fi

# Backup original Distribution file
cp "$DISTRIBUTION_FILE" "$DISTRIBUTION_FILE.backup"

# Replace version check: '26.1' -> '99.0'
sed -i '' "s/'26.1'/'99.0'/g" "$DISTRIBUTION_FILE" || print_error "Failed to modify Distribution file"

# Verify modification
if grep -q "'99.0'" "$DISTRIBUTION_FILE"; then
    print_step "Version check successfully modified (26.1 -> 99.0)"
else
    print_error "Failed to verify modification"
fi

# Step 7: Repackage
print_step "Repackaging modified drivers..."
pkgutil --flatten "$EXTRACTED_DIR" "$MODIFIED_PKG" || print_error "Failed to repackage"

# Step 8: Verify output
if [ -f "$MODIFIED_PKG" ]; then
    SIZE=$(du -h "$MODIFIED_PKG" | cut -f1)
    print_step "Success! Modified package created: $MODIFIED_PKG ($SIZE)"
else
    print_error "Modified package not created"
fi

# Step 9: Show installation instructions
echo
echo "======================================"
echo -e "${GREEN}Modification Complete!${NC}"
echo "======================================"
echo
echo "To install the modified drivers:"
echo "  1. GUI: Double-click '$MODIFIED_PKG'"
echo "  2. CLI: sudo installer -pkg $MODIFIED_PKG -target /"
echo
echo "Note: The package is unsigned. You may need to:"
echo "  - Allow installation from System Preferences > Security & Privacy"
echo "  - Or temporarily disable Gatekeeper (not recommended)"
echo
echo "Files created:"
echo "  - $MODIFIED_PKG (modified package ready to install)"
if [ -f "$PKG_FILE" ]; then
    echo "  - $PKG_FILE (original package for reference)"
fi
echo
