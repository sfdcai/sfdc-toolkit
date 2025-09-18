# SFDC DevOps Toolkit - Pure Batch Usage Guide

## Overview
This is a **pure batch file** implementation with **no PowerShell dependencies**. All functionality is implemented using standard Windows batch commands and the Salesforce CLI.

## Quick Start

### Option 1: Use the Launcher
```batch
launcher.bat
```

### Option 2: Run Directly
```batch
sfdc-toolkit.bat
```

### Option 3: Command Line Mode
```batch
sfdc-toolkit.bat help
```

## Available Commands

### 1. Check Prerequisites
```batch
sfdc-toolkit.bat check-prereqs
```
Checks for required tools:
- Salesforce CLI (sf)
- Git (optional)
- Visual Studio Code (optional)

### 2. Authorize a New Org
```batch
sfdc-toolkit.bat auth-org
```
Interactive authorization of a new Salesforce org.

### 3. List Authorized Orgs
```batch
sfdc-toolkit.bat list-orgs
```
Displays all currently authorized Salesforce orgs.

### 4. Compare Two Orgs
```batch
sfdc-toolkit.bat compare-orgs
```
Interactive comparison of two orgs with delta generation.

### 5. Deploy Metadata
```batch
sfdc-toolkit.bat deploy
```
Deploy metadata from delta package to target org.

### 6. Generate Manifest
```batch
sfdc-toolkit.bat generate-manifest
```
Generate package.xml manifest from source org.

### 7. Open Org in Browser
```batch
sfdc-toolkit.bat open-org
```
Open an authorized org in the default web browser.

## Command Line Parameters

### Basic Parameters
- `--help` or `-h` - Show help information
- `--version` or `-v` - Show version information

### Project Parameters
- `--project PATH` or `-p PATH` - Set project path
- `--source-org ALIAS` or `-s ALIAS` - Set source org alias
- `--dest-org ALIAS` or `-d ALIAS` - Set destination org alias
- `--api-version VERSION` - Set API version (default: 61.0)
- `--log-level LEVEL` - Set log level (INFO, DEBUG, WARN, ERROR)

## Usage Examples

### Example 1: Check Prerequisites
```batch
sfdc-toolkit.bat check-prereqs
```

### Example 2: Authorize Org with Parameters
```batch
sfdc-toolkit.bat --source-org "DEV" auth-org
```

### Example 3: Compare Orgs with Parameters
```batch
sfdc-toolkit.bat --source-org "DEV" --dest-org "PROD" --project "C:\MyProject" compare-orgs
```

### Example 4: Deploy with Custom API Version
```batch
sfdc-toolkit.bat --dest-org "PROD" --api-version "60.0" deploy
```

### Example 5: Generate Manifest
```batch
sfdc-toolkit.bat --source-org "DEV" --project "C:\MyProject" generate-manifest
```

## Interactive Mode

Run without any parameters to enter interactive mode:
```batch
sfdc-toolkit.bat
```

This will show a menu with numbered options:
```
Core DevOps Operations
--------------------------
[1] Check Prerequisites
[2] Authorize New Org
[3] List Authorized Orgs
[4] Compare Orgs & Generate Delta
[5] Deploy Metadata
[6] Generate Manifest
[7] Open Org in Browser

[H] Help
[V] Version
[Q] Quit
```

## Common Workflows

### Workflow 1: Complete Comparison and Deployment
```batch
# Step 1: Check prerequisites
sfdc-toolkit.bat check-prereqs

# Step 2: Authorize orgs (if needed)
sfdc-toolkit.bat auth-org

# Step 3: Compare orgs
sfdc-toolkit.bat --source-org "DEV" --dest-org "PROD" compare-orgs

# Step 4: Deploy changes
sfdc-toolkit.bat --dest-org "PROD" deploy
```

### Workflow 2: Generate and Deploy Manifest
```batch
# Step 1: Generate manifest from source org
sfdc-toolkit.bat --source-org "DEV" generate-manifest

# Step 2: Deploy using the generated manifest
sfdc-toolkit.bat --dest-org "PROD" deploy
```

## File Structure

After running operations, your project will have this structure:
```
Your-Project/
├── .sfdc-toolkit/
│   └── toolkit.log          # Log file
├── _source_metadata/        # Retrieved from source org
├── _target_metadata/        # Retrieved from target org
├── delta-deployment/        # Generated delta package
│   └── package.xml         # Deployment manifest
└── package.xml             # Generated manifest (if using generate-manifest)
```

## Logging

All operations are logged to: `.sfdc-toolkit\toolkit.log`

Log levels:
- **INFO**: General information
- **DEBUG**: Detailed debugging information
- **WARN**: Warnings
- **ERROR**: Errors

## Error Handling

The toolkit includes comprehensive error handling:
- Checks for required tools
- Validates org connections
- Handles deployment failures
- Provides clear error messages

## Troubleshooting

### Salesforce CLI Not Found
Install Salesforce CLI from: https://developer.salesforce.com/tools/sfdxcli

### Permission Issues
- Ensure you have write access to the project directory
- Run as Administrator if needed

### Org Authorization Issues
- Check your internet connection
- Verify org credentials
- Ensure the org is accessible

### Deployment Failures
- Check the log file for detailed error messages
- Verify the delta package was generated correctly
- Ensure target org has sufficient permissions

## Features

### Core Features
- ✅ Pure batch file implementation
- ✅ No PowerShell dependencies
- ✅ Interactive and command-line modes
- ✅ Comprehensive error handling
- ✅ Detailed logging
- ✅ Cross-Windows compatibility

### Salesforce Operations
- ✅ Org authorization and management
- ✅ Metadata comparison and delta generation
- ✅ Deployment with test execution
- ✅ Manifest generation
- ✅ Browser integration

### Project Management
- ✅ Self-contained project structure
- ✅ Automatic directory creation
- ✅ Configuration management
- ✅ Log file management

## Requirements

### Required
- Windows 7 or higher
- Salesforce CLI (sf)

### Optional
- Git (for version control)
- Visual Studio Code (for visual comparisons)

## Support

For issues or questions:
1. Check the log file: `.sfdc-toolkit\toolkit.log`
2. Run with debug logging: `--log-level DEBUG`
3. Verify prerequisites: `check-prereqs`

## Version Information

- **Version**: 14.2.0
- **Author**: Amit Bhardwaj
- **Type**: Pure Batch Implementation
- **Compatibility**: Windows 7, 8, 10, 11
