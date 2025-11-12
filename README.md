# Hewlett Packard Printer Drivers for macOS

This repository contains an automated script and instructions for modifying Hewlett Packard printer drivers for macOS to remove version restrictions.

The original HP drivers have a version check that prevents installation on newer macOS versions. This script modifies the package to work on any macOS version.

## Download Original Drivers

Download the original HP printer drivers from the official HP FTP server:

**Direct Download:** [HewlettPackardPrinterDrivers.dmg](https://ftp.hp.com/pub/softlib/software12/HP_Quick_Start/osx/Applications/ASU/HewlettPackardPrinterDrivers.dmg)

After downloading the DMG file:
1. Mount the DMG by double-clicking it
2. Copy `HewlettPackardPrinterDrivers.pkg` to your working directory
3. Follow the modification instructions below

## Supported Printers

- **HP LaserJet P1102**
- Other compatible HP printer models

## System Requirements

- macOS (any version - version restrictions removed)
- Administrator privileges for installation

## Quick Start

### Automated Method (Recommended)

Use the provided script to automatically download, modify, and repackage the drivers:

```bash
./modify-hp-drivers.sh
```

The script will:
1. Download the original drivers from HP
2. Extract and modify the version restrictions
3. Create `HewlettPackardPrinterDrivers-modified.pkg`

Then install the modified package:
```bash
sudo installer -pkg HewlettPackardPrinterDrivers-modified.pkg -target /
```

### Manual Method

If you prefer to do it manually:

1. **Download** the original drivers from HP (see link above)
2. **Modify** the package following the instructions below
3. **Install** the modified package

## Modifying the Package Manually

Here's the complete manual process to remove macOS version restrictions:

### Step 1: Extract the Package

```bash
# Extract the package contents
pkgutil --expand HewlettPackardPrinterDrivers.pkg extracted
```

This decompresses the package into a directory structure with:
- `Distribution` - XML file containing installation logic and version checks
- `Resources/` - Installer resources (license, localization files)
- `HewlettPackardPrinterDrivers.pkg/` - The actual driver package

### Step 2: Modify Version Check

Edit the `extracted/Distribution` file:

```bash
# Open the file with any text editor
nano extracted/Distribution
```

Find the line with version check (around line 16):

```xml
if (system.compareVersions(system.version.ProductVersion, '26.1') &gt; 0) {
```

Change `'26.1'` to `'99.0'` to remove practical version limits:

```xml
if (system.compareVersions(system.version.ProductVersion, '99.0') &gt; 0) {
```

This means the installer will work on any macOS version up to 99.0.

**Alternative using sed:**

```bash
sed -i '' "s/'26.1'/'99.0'/g" extracted/Distribution
```

### Step 3: Repackage

```bash
# Flatten the modified package back to .pkg format
pkgutil --flatten extracted HewlettPackardPrinterDrivers-modified.pkg
```

### Step 4: Replace Original (Optional)

```bash
# Keep original for reference
mv HewlettPackardPrinterDrivers.pkg HewlettPackardPrinterDrivers-original.pkg

# Use modified version as main
mv HewlettPackardPrinterDrivers-modified.pkg HewlettPackardPrinterDrivers.pkg

# Clean up extracted directory
rm -rf extracted
```

### Complete One-Liner Script

```bash
# Extract, modify, and repackage in one go
pkgutil --expand HewlettPackardPrinterDrivers.pkg extracted && \
sed -i '' "s/'26.1'/'99.0'/g" extracted/Distribution && \
pkgutil --flatten extracted HewlettPackardPrinterDrivers-modified.pkg && \
rm -rf extracted
```

## Understanding the Modification

### What Was Changed

The original package contained a version check that prevented installation on macOS versions newer than 26.1. The modification changes this limit to 99.0, effectively removing the restriction for all current and foreseeable macOS versions.

### What Was NOT Changed

- **Driver binaries** - No modifications to actual printer drivers
- **Driver functionality** - All features remain identical
- **Package signature** - Package is no longer signed (normal for modified packages)

### Version Reference

- macOS 15.x (Sequoia) = Darwin 25.x
- macOS 14.x (Sonoma) = Darwin 24.x
- macOS 13.x (Ventura) = Darwin 23.x

Original limit of 26.1 meant the drivers would work up to early macOS 16.x versions.

## Troubleshooting

### Installer Says "Cannot Install on This Version"

This should not happen with the modified package. If it does:

1. Verify you're using the modified package (not original)
2. Check the Distribution file was properly modified
3. Ensure the package was correctly flattened

### Installation Requires Allowing Unsigned Packages

Modified packages lose their signature. On newer macOS versions:

```bash
# Disable Gatekeeper temporarily (not recommended for production)
sudo spctl --master-disable

# Install the package
sudo installer -pkg HewlettPackardPrinterDrivers.pkg -target /

# Re-enable Gatekeeper
sudo spctl --master-enable
```

**Better approach:** Re-sign the package if you have a Developer ID:

```bash
productsign --sign "Developer ID Installer: Your Name" \
    HewlettPackardPrinterDrivers.pkg \
    HewlettPackardPrinterDrivers-signed.pkg
```

## Uninstallation

To remove the drivers:

```bash
# List installed HP packages
pkgutil --pkgs | grep -i hewlett

# View files installed by the package
pkgutil --files com.apple.pkg.HewlettPackardPrinterDrivers

# Note: macOS doesn't have built-in pkg uninstaller
# You'll need to manually remove files listed above
```

## Notes

- Always backup your system before installing modified packages
- Modified packages are unsigned and may require security adjustments
- The modification only removes version checks, not actual compatibility issues
- Test printer functionality after installation
- For production environments, consider proper code signing

## Support

For technical support with HP printers:
- [HP Support](https://support.hp.com/)
- [HP Drivers & Downloads](https://support.hp.com/drivers)

For issues with this modified package, refer to the modification process above.

## Disclaimer

This repository provides modified drivers "as is". Use at your own risk. The modification only changes installation requirements, not driver functionality. Ensure the drivers are compatible with your specific printer model before installation. Modified packages may not install on systems with strict security policies.

## References

- [macOS pkgutil documentation](https://ss64.com/osx/pkgutil.html)
- [Modifying macOS Packages Guide](https://gist.github.com/pavelbinar/e14bb47f98768d83828bdee89a47490e)
