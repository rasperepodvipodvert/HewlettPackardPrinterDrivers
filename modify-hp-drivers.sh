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
MOUNT_POINT=""

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
    if [ -n "$MOUNT_POINT" ] && [ -d "$MOUNT_POINT" ]; then
        hdiutil detach "$MOUNT_POINT" 2>/dev/null || true
    fi

    # Try to unmount any HP-related volumes as fallback
    for vol in /Volumes/HP*; do
        if [ -d "$vol" ]; then
            hdiutil detach "$vol" 2>/dev/null || true
        fi
    done

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

    # Step 2: Mount DMG and get mount point
    print_step "Mounting DMG..."
    MOUNT_OUTPUT=$(hdiutil attach "$DMG_FILE" -nobrowse 2>&1) || print_error "Failed to mount DMG"

    # Extract mount point from hdiutil output (last column)
    MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep "/Volumes/" | awk '{print $NF}' | head -1)

    if [ -z "$MOUNT_POINT" ] || [ ! -d "$MOUNT_POINT" ]; then
        print_error "Failed to determine mount point"
    fi

    print_step "DMG mounted at: $MOUNT_POINT"

    # Step 3: Find and copy PKG from DMG
    print_step "Searching for package file in DMG..."

    # Try to find the pkg file (case insensitive, recursive search)
    PKG_PATH=$(find "$MOUNT_POINT" -iname "*.pkg" -type f 2>/dev/null | grep -i "HewlettPackard" | head -1)

    if [ -z "$PKG_PATH" ]; then
        # If specific search fails, try any .pkg file
        PKG_PATH=$(find "$MOUNT_POINT" -iname "*.pkg" -type f 2>/dev/null | head -1)
    fi

    if [ -n "$PKG_PATH" ] && [ -f "$PKG_PATH" ]; then
        print_step "Found package: $(basename "$PKG_PATH")"
        print_step "Copying package..."
        cp "$PKG_PATH" "./$PKG_FILE" || print_error "Failed to copy package"
    else
        print_error "Package not found in DMG. Contents of DMG:\n$(ls -R "$MOUNT_POINT")"
    fi

    # Step 4: Unmount DMG
    print_step "Unmounting DMG..."
    hdiutil detach "$MOUNT_POINT" -quiet || print_warning "Failed to unmount DMG"
    MOUNT_POINT=""

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

# Show original version check
print_step "Checking original version restrictions..."
if grep -q "ProductVersion" "$DISTRIBUTION_FILE"; then
    echo "Found version checks in Distribution file:"
    grep "ProductVersion" "$DISTRIBUTION_FILE" | head -3
else
    print_warning "No ProductVersion checks found in Distribution file"
fi

# Try multiple version patterns that might be in the file
VERSION_MODIFIED=false

# Find and replace version in ProductVersion comparison
# Pattern: system.compareVersions(system.version.ProductVersion, 'X.X')
# Replace any version number with 99.0
if grep -q "system.version.ProductVersion" "$DISTRIBUTION_FILE"; then
    # Replace version in single quotes (most common)
    if grep -q "ProductVersion, '[0-9]" "$DISTRIBUTION_FILE"; then
        sed -i '' -E "s/(ProductVersion, ')([0-9]+\.[0-9]+)/\199.0/g" "$DISTRIBUTION_FILE"
        VERSION_MODIFIED=true
    fi

    # Replace version in double quotes
    if grep -q 'ProductVersion, "[0-9]' "$DISTRIBUTION_FILE"; then
        sed -i '' -E 's/(ProductVersion, ")([0-9]+\.[0-9]+)/\199.0/g' "$DISTRIBUTION_FILE"
        VERSION_MODIFIED=true
    fi
fi

# Verify modification
if [ "$VERSION_MODIFIED" = true ]; then
    print_step "Version check successfully modified"
    echo "New version checks:"
    grep "ProductVersion" "$DISTRIBUTION_FILE" | head -3 || echo "(No ProductVersion lines found after modification)"
else
    print_warning "No known version patterns found to modify. Package may work without changes."
    echo "Distribution file content (first 30 lines):"
    head -30 "$DISTRIBUTION_FILE"
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
